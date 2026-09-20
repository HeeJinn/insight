import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';
import 'package:image/image.dart' as img;
import 'package:lottie/lottie.dart';
import 'package:permission_handler/permission_handler.dart';
import '../app_theme.dart';
import '../core/widgets/core_widgets.dart';
import '../models/attendance.dart';
import '../models/session_entry.dart';
import '../models/student.dart';
import '../providers/settings_provider.dart';
import '../providers/sessions_provider.dart';
import '../services/captured_file_cleanup.dart';
import '../services/face_processor.dart';
import '../services/live_face_tracker.dart';
import 'app_chrome.dart';
import 'biometric_indicators.dart';
import 'face_overlay_painter.dart';
import 'responsive_utils.dart';

class CameraScanner extends ConsumerStatefulWidget {
  final Box<Student> studentsBox;
  final Box<Attendance> attendanceBox;

  const CameraScanner({
    super.key,
    required this.studentsBox,
    required this.attendanceBox,
  });

  @override
  ConsumerState<CameraScanner> createState() => _CameraScannerState();
}

class _CameraScannerState extends ConsumerState<CameraScanner>
    with WidgetsBindingObserver {
  CameraController? _controller;
  FaceProcessor? _faceProcessor;
  LiveFaceTracker? _liveFaceTracker;
  // A dedicated notifier (rather than a plain field + setState) so the
  // ~8/sec live-tracking updates only repaint the camera overlay, instead
  // of rebuilding this whole widget's badges/panels/Lottie setup on every
  // tick.
  final ValueNotifier<LiveFaceTrackingFrame?> _liveFaceFrameNotifier =
      ValueNotifier(null);
  bool _isTrackingFace = false;
  DateTime _lastTrackedAt = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _liveTrackingInterval = Duration(milliseconds: 120);
  String? _recognizedStudent;
  String _statusLabel = 'Waiting for camera access';
  bool _isProcessing = false;
  bool _isStreaming = false;
  bool _cameraDenied = false;
  bool _initializationFailed = false;
  DateTime _lastProcessedAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastRecognitionAt = DateTime.fromMillisecondsSinceEpoch(0);
  final Duration _recognitionCooldown = const Duration(seconds: 2);
  static const Duration _attendanceDedupeWindow = Duration(minutes: 1);
  final Map<String, DateTime> _recentAttendanceByStudent = {};
  static const Duration _streamScanInterval = Duration(milliseconds: 220);
  static const Duration _snapshotScanInterval = Duration(milliseconds: 1150);
  Timer? _cooldownTicker;
  Timer? _snapshotTicker;
  int _cooldownSecondsLeft = 0;

  bool get _usesSnapshotScanning =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  bool get _requiresRuntimeCameraPermission =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!kIsWeb) {
      for (final log in widget.attendanceBox.values) {
        final previous = _recentAttendanceByStudent[log.studentId];
        if (previous == null || log.timestamp.isAfter(previous)) {
          _recentAttendanceByStudent[log.studentId] = log.timestamp;
        }
      }
      _faceProcessor = FaceProcessor();
      _liveFaceTracker = LiveFaceTracker();
      if (_requiresRuntimeCameraPermission) {
        unawaited(_requestPermissions());
      } else {
        unawaited(_initializeCamera());
      }
    }
  }

  Future<void> _requestPermissions() async {
    final status = await Permission.camera.request();
    if (!mounted) {
      return;
    }

    if (status.isGranted) {
      setState(() {
        _cameraDenied = false;
        _statusLabel = 'Preparing camera';
      });
      await _initializeCamera();
    } else {
      setState(() {
        _cameraDenied = true;
        _statusLabel = 'Camera permission is required';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera permission is required')),
      );
    }
  }

  Future<void> _initializeCamera() async {
    final oldController = _controller;
    _controller = null;
    if (oldController != null) {
      if (_usesSnapshotScanning || oldController.value.isStreamingImages) {
        await _stopScanning();
      }
      try {
        await oldController.dispose();
      } catch (e) {
        debugPrint('Error disposing old camera controller: $e');
      }
    }

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw StateError('No camera was found on this device.');
      }

      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        frontCamera,
        _usesSnapshotScanning ? ResolutionPreset.medium : ResolutionPreset.low,
        enableAudio: false,
      );

      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _initializationFailed = false;
        _statusLabel = _usesSnapshotScanning
            ? 'Align your face for a quick snapshot'
            : 'Center your face in the frame';
      });

      _startScanning();
    } catch (e) {
      debugPrint('Failed to initialize camera: $e');
      if (!mounted) {
        return;
      }
      setState(() {
        _initializationFailed = true;
        _statusLabel = 'Unable to initialize the camera';
      });
    }
  }

  void _startScanning() {
    if (_usesSnapshotScanning) {
      _startSnapshotScanning();
      return;
    }

    final controller = _controller;
    if (controller == null ||
        widget.studentsBox.isEmpty ||
        _isStreaming ||
        !controller.value.isInitialized) {
      return;
    }

    _isStreaming = true;
    controller.startImageStream((CameraImage image) async {
      if (!mounted) {
        return;
      }
      unawaited(_updateLiveFaceTracking(image, controller));
      if (_isProcessing) {
        return;
      }
      final now = DateTime.now();
      if (now.difference(_lastProcessedAt) < _streamScanInterval) {
        return;
      }
      _lastProcessedAt = now;

      _isProcessing = true;
      try {
        final recognized = await _processImage(image);
        if (!mounted) {
          return;
        }

        _handleRecognition(recognized);
      } catch (e) {
        debugPrint('Error processing image: $e');
        if (mounted) {
          setState(() => _statusLabel = 'Scanning paused, trying again');
        }
      } finally {
        _isProcessing = false;
      }
    });
  }

  void _startSnapshotScanning() {
    final controller = _controller;
    if (controller == null ||
        widget.studentsBox.isEmpty ||
        _isStreaming ||
        !controller.value.isInitialized) {
      return;
    }

    _snapshotTicker?.cancel();
    _isStreaming = true;
    _snapshotTicker = Timer.periodic(_snapshotScanInterval, (timer) async {
      if (!mounted) {
        timer.cancel();
        _isStreaming = false;
        return;
      }
      if (_isProcessing || controller.value.isTakingPicture) {
        return;
      }

      final now = DateTime.now();
      if (now.difference(_lastProcessedAt) < _snapshotScanInterval) {
        return;
      }
      _lastProcessedAt = now;

      _isProcessing = true;
      try {
        final recognized = await _processStillCapture();
        if (!mounted) {
          return;
        }
        _handleRecognition(recognized);
      } catch (e) {
        debugPrint('Error processing snapshot capture: $e');
        if (mounted) {
          setState(() => _statusLabel = 'Snapshot scan paused, trying again');
        }
      } finally {
        _isProcessing = false;
      }
    });
  }

  /// Updates the live face-tracking overlay from the same stream frames
  /// used for recognition, throttled and gated independently so a slow
  /// mesh/contour detection pass never blocks (or is blocked by) the
  /// recognition pipeline.
  Future<void> _updateLiveFaceTracking(
    CameraImage image,
    CameraController controller,
  ) async {
    final tracker = _liveFaceTracker;
    if (tracker == null || !tracker.isSupported || _isTrackingFace) {
      return;
    }
    final now = DateTime.now();
    if (now.difference(_lastTrackedAt) < _liveTrackingInterval) {
      return;
    }
    _lastTrackedAt = now;

    _isTrackingFace = true;
    try {
      final frame = await tracker.processCameraImage(
        image,
        camera: controller.description,
        deviceOrientation: controller.value.deviceOrientation,
      );
      if (!mounted) {
        return;
      }
      _liveFaceFrameNotifier.value = frame;
    } finally {
      _isTrackingFace = false;
    }
  }

  Future<void> _stopScanning() async {
    _snapshotTicker?.cancel();
    _snapshotTicker = null;
    if (_usesSnapshotScanning) {
      _isStreaming = false;
      return;
    }

    final controller = _controller;
    if (controller == null) {
      _isStreaming = false;
      return;
    }
    if (!controller.value.isStreamingImages) {
      _isStreaming = false;
      return;
    }
    await controller.stopImageStream();
    _isStreaming = false;
  }

  Future<String?> _processImage(CameraImage image) async {
    final processor = _faceProcessor;
    final controller = _controller;
    if (processor == null || controller == null) {
      return null;
    }

    final threshold = ref.read(recognitionThresholdProvider);
    final convertedImage = processor.convertCameraImage(image);
    final rotatedImage = processor.rotateImage(
      convertedImage,
      rotationDegrees: _rotationCompensation(controller),
    );
    final bbox = await processor.detectFace(rotatedImage);
    final cropped = processor.cropFace(rotatedImage, bbox);
    final embedding = await processor.recognizeFace(cropped);
    final mirroredCrop = processor.flipImageHorizontally(
      img.Image.from(cropped),
    );
    final mirroredEmbedding = await processor.recognizeFace(mirroredCrop);
    final students = widget.studentsBox.values.toList(growable: false);
    return processor.recognizeStudent(
      students,
      embedding,
      threshold: threshold,
      alternateEmbeddings: [mirroredEmbedding],
    );
  }

  Future<String?> _processStillCapture() async {
    final processor = _faceProcessor;
    final controller = _controller;
    if (processor == null || controller == null) {
      return null;
    }

    final threshold = ref.read(recognitionThresholdProvider);
    final picture = await controller.takePicture();
    try {
      final bytes = await picture.readAsBytes();
      final capturedImage = img.decodeImage(bytes);
      if (capturedImage == null) {
        throw StateError('The captured snapshot could not be decoded.');
      }

      final bbox = await processor.detectFace(capturedImage);
      if (mounted) {
        _liveFaceFrameNotifier.value = LiveFaceTrackingFrame(
          geometry: NormalizedBoxGeometry(
            left: bbox[0],
            top: bbox[1],
            width: bbox[2],
            height: bbox[3],
          ),
        );
      }
      final cropped = processor.cropFace(capturedImage, bbox);
      final embedding = await processor.recognizeFace(cropped);
      final mirroredCrop = processor.flipImageHorizontally(
        img.Image.from(cropped),
      );
      final mirroredEmbedding = await processor.recognizeFace(mirroredCrop);
      final students = widget.studentsBox.values.toList(growable: false);
      return await processor.recognizeStudent(
        students,
        embedding,
        threshold: threshold,
        alternateEmbeddings: [mirroredEmbedding],
      );
    } finally {
      await deleteCapturedFile(picture.path);
    }
  }

  int _rotationCompensation(CameraController controller) {
    final deviceRotation = switch (controller.value.deviceOrientation) {
      DeviceOrientation.portraitUp => 0,
      DeviceOrientation.landscapeLeft => 90,
      DeviceOrientation.portraitDown => 180,
      DeviceOrientation.landscapeRight => 270,
    };

    final sensorOrientation = controller.description.sensorOrientation;
    if (controller.description.lensDirection == CameraLensDirection.front) {
      return (sensorOrientation + deviceRotation) % 360;
    }

    return (sensorOrientation - deviceRotation + 360) % 360;
  }

  bool _logAttendanceIfNeeded(String studentId) {
    final now = DateTime.now();
    final recent = _recentAttendanceByStudent[studentId];
    if (recent != null && now.difference(recent) < _attendanceDedupeWindow) {
      return false;
    }

    final nowMinute = now.hour * 60 + now.minute;
    SessionEntry? activeSession;
    for (final session in ref.read(sessionsProvider)) {
      if (nowMinute >= session.startMinuteOfDay &&
          nowMinute <= session.endMinuteOfDay) {
        activeSession = session;
        break;
      }
    }

    final attendance = Attendance(
      studentId: studentId,
      timestamp: now,
      sessionTitle: activeSession?.title,
      room: activeSession?.room,
    );
    widget.attendanceBox.add(attendance);
    _recentAttendanceByStudent[studentId] = now;
    return true;
  }

  int _remainingCooldownSeconds(String studentId) {
    final recent = _recentAttendanceByStudent[studentId];
    if (recent == null) {
      return 0;
    }
    final elapsed = DateTime.now().difference(recent);
    final remaining = _attendanceDedupeWindow - elapsed;
    if (remaining.isNegative) {
      return 0;
    }
    return remaining.inSeconds;
  }

  void _handleRecognition(String? recognized) {
    if (recognized == null ||
        recognized == _recognizedStudent ||
        DateTime.now().difference(_lastRecognitionAt) <= _recognitionCooldown) {
      return;
    }

    _lastRecognitionAt = DateTime.now();
    final didLog = _logAttendanceIfNeeded(recognized);
    final remaining = _remainingCooldownSeconds(recognized);
    setState(() {
      _recognizedStudent = recognized;
      _statusLabel = didLog
          ? 'Attendance logged'
          : 'Already logged recently. Ask student to step aside.';
      _cooldownSecondsLeft = remaining;
    });
    _startCooldownTicker(recognized);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _recognizedStudent = null;
          _statusLabel = _usesSnapshotScanning
              ? 'Align your face for a quick snapshot'
              : 'Center your face in the frame';
        });
      }
    });
  }

  void _startCooldownTicker(String studentId) {
    _cooldownTicker?.cancel();
    _cooldownTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final remaining = _remainingCooldownSeconds(studentId);
      if (remaining <= 0) {
        setState(() => _cooldownSecondsLeft = 0);
        timer.cancel();
        return;
      }
      setState(() => _cooldownSecondsLeft = remaining);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (kIsWeb) {
      return;
    }
    if (state == AppLifecycleState.resumed) {
      _startScanning();
      return;
    }
    unawaited(_stopScanning());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cooldownTicker?.cancel();
    _snapshotTicker?.cancel();
    final controller = _controller;
    if (controller != null) {
      if (_usesSnapshotScanning || controller.value.isStreamingImages) {
        unawaited(_stopScanning());
      }
      controller.dispose();
    }
    _faceProcessor?.dispose();
    unawaited(_liveFaceTracker?.close());
    _liveFaceFrameNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Face recognition is not supported on web. Please run this app on Android, iOS, or desktop.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_cameraDenied) {
      return const _ScannerStatePanel(
        icon: Icons.no_photography_outlined,
        title: 'Camera permission required',
        subtitle:
            'Allow camera access from system settings to start live recognition.',
      );
    }

    if (_initializationFailed) {
      return _ScannerStatePanel(
        icon: Icons.camera_alt_outlined,
        title: 'Camera unavailable',
        subtitle: _statusLabel,
      );
    }

    if (_controller == null || !_controller!.value.isInitialized) {
      return _ScannerLoadingState(statusLabel: _statusLabel);
    }

    final threshold = ref.watch(recognitionThresholdProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = AppBreakpoints.isCompact(constraints.maxWidth);

        return Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: ValueListenableBuilder<LiveFaceTrackingFrame?>(
                valueListenable: _liveFaceFrameNotifier,
                builder: (context, frame, _) {
                  return CoverCameraPreview(
                    controller: _controller!,
                    foregroundPainter: FaceTrackingOverlayPainter(
                      frame: frame,
                      color: _recognizedStudent != null
                          ? const Color(0xFF00E599)
                          : Colors.white,
                    ),
                  );
                },
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0x99243578),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.42),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TelemetryBadge(
                      label: '${widget.studentsBox.length} STUDENTS LOADED',
                      icon: Icons.badge_outlined,
                      statusColor: Colors.white,
                    ),
                    if (!compact)
                      TelemetryBadge(
                        label: 'THRESHOLD ${threshold.toStringAsFixed(2)}',
                        icon: Icons.tune,
                        statusColor: Colors.white,
                      ),
                    if (_isProcessing)
                      const TelemetryBadge(
                        label: 'INFERENCE BUSY',
                        isLive: true,
                        statusColor: Color(0xFFFBBF24),
                      ),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: compact ? 300 : 440),
                  child: AppPanel(
                    radius: 16,
                    showReticles: true,
                    padding: EdgeInsets.all(compact ? 12 : 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            TelemetryBadge(
                              label: _recognizedStudent == null
                                  ? (_usesSnapshotScanning
                                      ? 'SNAPSHOT RETICLE'
                                      : 'LIVE SCAN ACTIVE')
                                  : (_cooldownSecondsLeft > 0
                                      ? 'VERIFIED • LOCK ${_cooldownSecondsLeft}S'
                                      : 'ATTENDANCE CAPTURED'),
                              statusColor: _recognizedStudent == null
                                  ? context.appColors.accent
                                  : context.appColors.success,
                              isLive: _recognizedStudent == null,
                            ),
                            const Spacer(),
                            if (_recognizedStudent != null)
                              // "Success" by Darius Afchar, via LottieFiles
                              // (Lottie Simple License).
                              SizedBox(
                                width: 32,
                                height: 32,
                                child: Lottie.asset(
                                  'assets/animations/success_checkmark.json',
                                  repeat: false,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    width: 22,
                                    height: 22,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF00E599),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.check,
                                      size: 14,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _recognizedStudent == null
                              ? _statusLabel
                              : 'Verified: $_recognizedStudent',
                          maxLines: compact ? 2 : 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: compact ? 13 : 15,
                            fontWeight: _recognizedStudent != null
                                ? FontWeight.w700
                                : FontWeight.w500,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ScannerLoadingState extends StatelessWidget {
  final String statusLabel;

  const _ScannerLoadingState({required this.statusLabel});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: AppPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  gradient: context.appDecorations.accentGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: context.appDecorations.panelShadow,
                ),
                child: const Icon(
                  Icons.camera_alt_outlined,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(height: 16),
              Text(
                statusLabel,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScannerStatePanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _ScannerStatePanel({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: AppPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: context.appDecorations.orangeGradient,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: context.appDecorations.panelShadow,
                ),
                child: Icon(icon, color: Colors.white, size: 30),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

