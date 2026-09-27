import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/widgets/cover_camera_preview.dart';
import '../models/attendance.dart';
import '../models/student.dart';
import '../providers/settings_provider.dart';
import '../providers/sessions_provider.dart';
import '../services/camera_rotation.dart';
import '../services/captured_file_cleanup.dart';
import '../services/face_processor.dart';
import '../services/live_face_tracker.dart';
import '../services/session_clock.dart';
import '../ui/insight_ui.dart';
import 'face_overlay_painter.dart';

enum ScanEventKind {
  /// A new attendance record was written.
  checkedIn,

  /// The student already has a record for this session today.
  alreadyCheckedIn,

  /// A face was seen repeatedly but matched nobody.
  unknown,
}

class ScanEvent {
  const ScanEvent(this.kind, {this.student, this.attendance, this.at});

  final ScanEventKind kind;
  final Student? student;

  /// The new record for [ScanEventKind.checkedIn], or the earlier one for
  /// [ScanEventKind.alreadyCheckedIn].
  final Attendance? attendance;
  final DateTime? at;
}

/// The kiosk's camera: shows the live preview with a face-tracking overlay,
/// recognizes enrolled students, writes attendance, and reports each
/// outcome through [onEvent]. The kiosk decides how to present outcomes.
class CameraScanner extends ConsumerStatefulWidget {
  const CameraScanner({
    super.key,
    required this.studentsBox,
    required this.attendanceBox,
    required this.onEvent,
    this.enabled = true,
    this.pausedLabel = 'Check-in paused',
  });

  final Box<Student> studentsBox;
  final Box<Attendance> attendanceBox;
  final ValueChanged<ScanEvent> onEvent;

  /// When false the preview stays live but nothing is recognized or logged.
  final bool enabled;
  final String pausedLabel;

  @override
  ConsumerState<CameraScanner> createState() => _CameraScannerState();
}

class _CameraScannerState extends ConsumerState<CameraScanner>
    with WidgetsBindingObserver {
  CameraController? _controller;
  FaceProcessor? _faceProcessor;
  LiveFaceTracker? _liveFaceTracker;
  // A dedicated notifier (rather than a plain field + setState) so the
  // ~8/sec live-tracking updates only repaint the camera overlay.
  final ValueNotifier<LiveFaceTrackingFrame?> _liveFaceFrameNotifier =
      ValueNotifier(null);
  bool _isTrackingFace = false;
  DateTime _lastTrackedAt = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _liveTrackingInterval = Duration(milliseconds: 120);

  String? _recognizedStudent;
  bool _highlight = false;
  String _statusLabel = 'Starting camera…';
  bool _isProcessing = false;
  bool _isStreaming = false;
  bool _cameraDenied = false;
  bool _initializationFailed = false;
  DateTime _lastProcessedAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastRecognitionAt = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _recognitionCooldown = Duration(seconds: 2);
  static const Duration _resultHold = Duration(seconds: 3);
  static const Duration _streamScanInterval = Duration(milliseconds: 220);
  static const Duration _snapshotScanInterval = Duration(milliseconds: 1150);
  Timer? _snapshotTicker;
  Timer? _resetTimer;

  // Unknown faces are reported only after several consecutive misses, and
  // at most once per [_unknownCooldown], so a half-turned head doesn't
  // flash "not recognized".
  int _consecutiveUnknown = 0;
  DateTime _lastUnknownAt = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _unknownCooldown = Duration(seconds: 5);
  int get _unknownThreshold => _usesSnapshotScanning ? 2 : 4;

  /// Students whose baselines came from the current face model. Profiles
  /// enrolled with an older pipeline cannot be matched and must be
  /// registered again.
  bool get _hasMatchableStudents =>
      widget.studentsBox.values.any(FaceProcessor.hasCompatibleEmbeddings);

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
    if (!mounted) return;

    if (status.isGranted) {
      setState(() {
        _cameraDenied = false;
        _statusLabel = 'Starting camera…';
      });
      await _initializeCamera();
    } else {
      setState(() => _cameraDenied = true);
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
      });

      _startScanning();
    } catch (e) {
      debugPrint('Failed to initialize camera: $e');
      if (!mounted) return;
      setState(() {
        _initializationFailed = true;
        _statusLabel = e is StateError
            ? e.message
            : 'The camera could not be started.';
      });
    }
  }

  bool get _canRecognize =>
      widget.enabled && _hasMatchableStudents && _recognizedStudent == null;

  void _startScanning() {
    if (_usesSnapshotScanning) {
      _startSnapshotScanning();
      return;
    }

    final controller = _controller;
    if (controller == null || _isStreaming || !controller.value.isInitialized) {
      return;
    }

    _isStreaming = true;
    controller.startImageStream((CameraImage image) async {
      if (!mounted) return;
      unawaited(_updateLiveFaceTracking(image, controller));
      if (_isProcessing || !_canRecognize) return;
      final now = DateTime.now();
      if (now.difference(_lastProcessedAt) < _streamScanInterval) return;
      _lastProcessedAt = now;

      // Recognition time is measured from the moment the frame arrives
      // until the attendance record is written.
      final scanTimer = Stopwatch()..start();
      _isProcessing = true;
      try {
        final outcome = await _processImage(image);
        if (!mounted) return;
        _handleOutcome(outcome, scanTimer);
      } catch (e) {
        debugPrint('Error processing image: $e');
      } finally {
        _isProcessing = false;
      }
    });
  }

  void _startSnapshotScanning() {
    final controller = _controller;
    if (controller == null || _isStreaming || !controller.value.isInitialized) {
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
      if (_isProcessing ||
          controller.value.isTakingPicture ||
          !_canRecognize) {
        return;
      }

      final now = DateTime.now();
      if (now.difference(_lastProcessedAt) < _snapshotScanInterval) return;
      _lastProcessedAt = now;

      // Includes the snapshot capture itself, so the time covers capture,
      // processing, matching and logging.
      final scanTimer = Stopwatch()..start();
      _isProcessing = true;
      try {
        final outcome = await _processStillCapture();
        if (!mounted) return;
        _handleOutcome(outcome, scanTimer);
      } catch (e) {
        debugPrint('Error processing snapshot capture: $e');
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
    if (tracker == null || !tracker.isSupported || _isTrackingFace) return;
    final now = DateTime.now();
    if (now.difference(_lastTrackedAt) < _liveTrackingInterval) return;
    _lastTrackedAt = now;

    _isTrackingFace = true;
    try {
      final frame = await tracker.processCameraImage(
        image,
        camera: controller.description,
        deviceOrientation: controller.value.deviceOrientation,
      );
      if (!mounted) return;
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
    if (controller == null || !controller.value.isStreamingImages) {
      _isStreaming = false;
      return;
    }
    await controller.stopImageStream();
    _isStreaming = false;
  }

  Future<_ScanOutcome> _processImage(CameraImage image) async {
    final processor = _faceProcessor;
    final controller = _controller;
    if (processor == null || controller == null) {
      return const _ScanOutcome.none();
    }

    final scan = await processor.processCameraImage(
      image,
      rotationDegrees: cameraRotationCompensation(controller),
    );
    return _matchScan(processor, scan);
  }

  Future<_ScanOutcome> _processStillCapture() async {
    final processor = _faceProcessor;
    final controller = _controller;
    if (processor == null || controller == null) {
      return const _ScanOutcome.none();
    }

    final picture = await controller.takePicture();
    try {
      final bytes = await picture.readAsBytes();
      final scan = await processor.processEncodedImage(bytes);
      if (mounted) {
        _liveFaceFrameNotifier.value = scan == null
            ? null
            : LiveFaceTrackingFrame(
                geometry: NormalizedBoxGeometry(
                  left: scan.box[0],
                  top: scan.box[1],
                  width: scan.box[2],
                  height: scan.box[3],
                ),
              );
      }
      return await _matchScan(processor, scan);
    } finally {
      await deleteCapturedFile(picture.path);
    }
  }

  Future<_ScanOutcome> _matchScan(
    FaceProcessor processor,
    FaceScanResult? scan,
  ) async {
    if (scan == null) return const _ScanOutcome.none();
    final threshold = ref.read(recognitionThresholdProvider);
    final students = widget.studentsBox.values.toList(growable: false);
    final studentId = await processor.recognizeStudent(
      students,
      scan.embedding,
      threshold: threshold,
      alternateEmbeddings: [scan.mirroredEmbedding],
    );
    return _ScanOutcome(studentId, scan);
  }

  /// The student's earlier record for the current session today, or for
  /// today's general check-ins when no session is running.
  Attendance? _existingRecord(String studentId, String? sessionTitle) {
    final now = DateTime.now();
    for (final log in widget.attendanceBox.values) {
      if (log.studentId == studentId &&
          log.sessionTitle == sessionTitle &&
          isSameDay(log.timestamp, now)) {
        return log;
      }
    }
    return null;
  }

  void _handleOutcome(_ScanOutcome outcome, Stopwatch scanTimer) {
    final recognized = outcome.studentId;

    if (recognized == null) {
      if (outcome.scan == null) {
        _consecutiveUnknown = 0;
        return;
      }
      _consecutiveUnknown++;
      final now = DateTime.now();
      if (_consecutiveUnknown >= _unknownThreshold &&
          now.difference(_lastUnknownAt) > _unknownCooldown) {
        _consecutiveUnknown = 0;
        _lastUnknownAt = now;
        widget.onEvent(ScanEvent(ScanEventKind.unknown, at: now));
      }
      return;
    }

    _consecutiveUnknown = 0;
    if (DateTime.now().difference(_lastRecognitionAt) <= _recognitionCooldown) {
      return;
    }
    _lastRecognitionAt = DateTime.now();

    final student = widget.studentsBox.values
        .where((s) => s.id == recognized)
        .firstOrNull;
    final now = DateTime.now();
    final session = activeSessionAt(ref.read(sessionsProvider), now);
    final existing = _existingRecord(recognized, session?.title);

    final ScanEvent event;
    if (existing != null) {
      event = ScanEvent(
        ScanEventKind.alreadyCheckedIn,
        student: student,
        attendance: existing,
        at: now,
      );
    } else {
      final attendance = Attendance(
        studentId: recognized,
        timestamp: now,
        sessionTitle: session?.title,
        room: session?.room,
        latencyMs: scanTimer.elapsedMilliseconds,
      );
      widget.attendanceBox.add(attendance);
      event = ScanEvent(
        ScanEventKind.checkedIn,
        student: student,
        attendance: attendance,
        at: now,
      );
    }

    final scan = outcome.scan;
    if (scan != null) {
      debugPrint(
        'Recognized $recognized: pipeline ${scan.processingMs} ms, '
        'capture-to-log ${scanTimer.elapsedMilliseconds} ms',
      );
    }

    // Hold off on recognizing anyone else while the result is on screen.
    setState(() {
      _recognizedStudent = recognized;
      _highlight = true;
    });
    widget.onEvent(event);
    _resetTimer?.cancel();
    _resetTimer = Timer(_resultHold, () {
      if (mounted) {
        setState(() {
          _recognizedStudent = null;
          _highlight = false;
        });
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (kIsWeb) return;
    if (state == AppLifecycleState.resumed) {
      _startScanning();
      return;
    }
    unawaited(_stopScanning());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _snapshotTicker?.cancel();
    _resetTimer?.cancel();
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
      return const _CameraMessage(
        icon: CupertinoIcons.desktopcomputer,
        title: 'Not available on the web',
        message: 'Run Insight on a Mac, PC, iPhone or Android device to scan.',
      );
    }

    if (_cameraDenied) {
      return const _CameraMessage(
        icon: CupertinoIcons.video_camera,
        title: 'Camera access needed',
        message: 'Allow Insight to use the camera in system settings.',
      );
    }

    if (_initializationFailed) {
      return _CameraMessage(
        icon: CupertinoIcons.exclamationmark_triangle,
        title: 'Camera unavailable',
        message: _statusLabel,
      );
    }

    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return _CameraMessage(
        title: _statusLabel,
        loading: true,
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        ValueListenableBuilder<LiveFaceTrackingFrame?>(
          valueListenable: _liveFaceFrameNotifier,
          builder: (context, frame, _) => CoverCameraPreview(
            controller: controller,
            foregroundPainter: FaceTrackingOverlayPainter(
              frame: frame,
              color: _highlight
                  ? CupertinoColors.systemGreen.darkColor
                  : CupertinoColors.white,
            ),
          ),
        ),
        // A soft scrim at the bottom so the status capsule stays legible
        // over bright backgrounds.
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.center,
                end: Alignment.bottomCenter,
                colors: [Color(0x00000000), Color(0x66000000)],
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: ValueListenableBuilder<LiveFaceTrackingFrame?>(
              valueListenable: _liveFaceFrameNotifier,
              builder: (context, frame, _) =>
                  _StatusCapsule(label: _capsuleLabel(frame != null)),
            ),
          ),
        ),
      ],
    );
  }

  String _capsuleLabel(bool faceVisible) {
    if (!widget.enabled) return widget.pausedLabel;
    if (!_hasMatchableStudents) {
      return widget.studentsBox.isEmpty
          ? 'No students enrolled'
          : 'Students need to be re-enrolled';
    }
    if (_highlight) return 'Done';
    return faceVisible ? 'Hold still…' : 'Look at the camera';
  }
}

/// The glass capsule over the video that tells the person what to do.
class _StatusCapsule extends StatelessWidget {
  const _StatusCapsule({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return CupertinoTheme(
      data: const CupertinoThemeData(brightness: Brightness.dark),
      child: LiquidGlass(
        clear: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              label,
              key: ValueKey(label),
              style: InsightText.headline.copyWith(
                color: CupertinoColors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Loading, permission and error states, drawn on the dark camera well.
class _CameraMessage extends StatelessWidget {
  const _CameraMessage({
    required this.title,
    this.icon,
    this.message,
    this.loading = false,
  });

  final IconData? icon;
  final String title;
  final String? message;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    const muted = Color(0x99EBEBF5);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              const CupertinoActivityIndicator(
                radius: 14,
                color: CupertinoColors.white,
              )
            else if (icon != null)
              Icon(icon, size: 48, color: muted),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: InsightText.title3.copyWith(color: CupertinoColors.white),
            ),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: InsightText.subheadline.copyWith(color: muted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ScanOutcome {
  const _ScanOutcome(this.studentId, this.scan);
  const _ScanOutcome.none() : studentId = null, scan = null;

  final String? studentId;
  final FaceScanResult? scan;
}
