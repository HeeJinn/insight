import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';
import '../app_theme.dart';
import '../models/attendance.dart';
import '../models/student.dart';
import '../providers/settings_provider.dart';
import '../services/face_processor.dart';
import 'app_chrome.dart';
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

class _CameraScannerState extends ConsumerState<CameraScanner> {
  CameraController? _controller;
  FaceProcessor? _faceProcessor;
  String? _recognizedStudent;
  String _statusLabel = 'Waiting for camera access';
  bool _isProcessing = false;
  bool _cameraDenied = false;
  bool _initializationFailed = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _faceProcessor = FaceProcessor();
      _requestPermissions();
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
        ResolutionPreset.medium,
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
        _statusLabel = 'Center your face in the frame';
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
    final controller = _controller;
    if (controller == null || widget.studentsBox.isEmpty) {
      return;
    }

    controller.startImageStream((CameraImage image) async {
      if (_isProcessing) {
        return;
      }

      _isProcessing = true;
      try {
        final recognized = await _processImage(image);
        if (!mounted) {
          return;
        }

        if (recognized != null && recognized != _recognizedStudent) {
          setState(() {
            _recognizedStudent = recognized;
            _statusLabel = 'Attendance logged';
          });
          _logAttendance(recognized);
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) {
              setState(() {
                _recognizedStudent = null;
                _statusLabel = 'Center your face in the frame';
              });
            }
          });
        }
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
    final mirroredCrop = processor.flipImageHorizontally(img.Image.from(cropped));
    final mirroredEmbedding = await processor.recognizeFace(mirroredCrop);
    final students = widget.studentsBox.values.toList();
    return processor.recognizeStudent(
      students,
      embedding,
      threshold: threshold,
      alternateEmbeddings: [mirroredEmbedding],
    );
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

  void _logAttendance(String studentId) {
    final attendance = Attendance(
      studentId: studentId,
      timestamp: DateTime.now(),
    );
    widget.attendanceBox.add(attendance);
  }

  @override
  void dispose() {
    final controller = _controller;
    if (controller != null) {
      if (controller.value.isStreamingImages) {
        unawaited(controller.stopImageStream());
      }
      controller.dispose();
    }
    _faceProcessor?.dispose();
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
        final maxFrameWidth = (constraints.maxWidth - (compact ? 72 : 120))
            .clamp(190.0, 360.0)
            .toDouble();
        final maxFrameHeight = (constraints.maxHeight - (compact ? 250 : 220))
            .clamp(250.0, 430.0)
            .toDouble();

        var frameWidth = maxFrameWidth;
        var frameHeight = frameWidth * 1.26;
        if (frameHeight > maxFrameHeight) {
          frameHeight = maxFrameHeight;
          frameWidth = frameHeight / 1.26;
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: CameraPreview(_controller!),
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
                padding: const EdgeInsets.all(18),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _OverlayBadge(
                      icon: Icons.groups_2_outlined,
                      label: '${widget.studentsBox.length} students loaded',
                    ),
                    if (!compact)
                      _OverlayBadge(
                        icon: Icons.tune,
                        label: 'Threshold ${threshold.toStringAsFixed(2)}',
                      ),
                  ],
                ),
              ),
            ),
            Center(
              child: Container(
                width: frameWidth,
                height: frameHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.95),
                    width: 2.2,
                  ),
                  boxShadow: AppTheme.panelShadow,
                ),
                child: Stack(
                  children: const [
                    Positioned(
                      top: 14,
                      left: 14,
                      child: _CornerAccent(alignment: Alignment.topLeft),
                    ),
                    Positioned(
                      top: 14,
                      right: 14,
                      child: _CornerAccent(alignment: Alignment.topRight),
                    ),
                    Positioned(
                      bottom: 14,
                      left: 14,
                      child: _CornerAccent(alignment: Alignment.bottomLeft),
                    ),
                    Positioned(
                      bottom: 14,
                      right: 14,
                      child: _CornerAccent(alignment: Alignment.bottomRight),
                    ),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: compact ? 260 : 420),
                  child: AppPanel(
                    radius: compact ? 22 : 26,
                    padding: EdgeInsets.all(compact ? 12 : 18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppPillTag(
                          label: _recognizedStudent == null
                              ? 'Scanning live'
                              : 'Attendance captured',
                          backgroundColor: _recognizedStudent == null
                              ? AppTheme.accentSoft
                              : AppTheme.orangeSoft,
                          foregroundColor: _recognizedStudent == null
                              ? AppTheme.accentDark
                              : AppTheme.orange,
                          padding: EdgeInsets.symmetric(
                            horizontal: compact ? 10 : 14,
                            vertical: compact ? 8 : 10,
                          ),
                        ),
                        SizedBox(height: compact ? 8 : 10),
                        if (!compact) ...[
                          Text(
                            _recognizedStudent == null
                                ? 'Live Scan'
                                : 'Attendance Captured',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 6),
                        ],
                        Text(
                          _recognizedStudent == null
                              ? _statusLabel
                              : 'Attendance logged for $_recognizedStudent',
                          maxLines: compact ? 2 : 3,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium,
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
                  gradient: AppTheme.lilacGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: AppTheme.panelShadow,
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
                  gradient: AppTheme.orangeGradient,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: AppTheme.panelShadow,
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

class _OverlayBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _OverlayBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 44, maxWidth: 240),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CornerAccent extends StatelessWidget {
  final Alignment alignment;

  const _CornerAccent({required this.alignment});

  @override
  Widget build(BuildContext context) {
    final isLeft =
        alignment == Alignment.topLeft || alignment == Alignment.bottomLeft;
    final isTop =
        alignment == Alignment.topLeft || alignment == Alignment.topRight;

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        border: Border(
          top: isTop
              ? const BorderSide(color: Color(0xCCFFFFFF), width: 4)
              : BorderSide.none,
          left: isLeft
              ? const BorderSide(color: Color(0xCCFFFFFF), width: 4)
              : BorderSide.none,
          right: !isLeft
              ? const BorderSide(color: Color(0xCCFFFFFF), width: 4)
              : BorderSide.none,
          bottom: !isTop
              ? const BorderSide(color: Color(0xCCFFFFFF), width: 4)
              : BorderSide.none,
        ),
        borderRadius: BorderRadius.only(
          topLeft: isTop && isLeft ? const Radius.circular(16) : Radius.zero,
          topRight: isTop && !isLeft ? const Radius.circular(16) : Radius.zero,
          bottomLeft: !isTop && isLeft
              ? const Radius.circular(16)
              : Radius.zero,
          bottomRight: !isTop && !isLeft
              ? const Radius.circular(16)
              : Radius.zero,
        ),
      ),
    );
  }
}
