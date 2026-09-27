import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/widgets/cover_camera_preview.dart';
import '../services/camera_rotation.dart';
import '../services/captured_file_cleanup.dart';
import '../services/face_processor.dart';
import '../ui/insight_ui.dart';

extension CapturePoseText on CapturePose {
  String get instruction => switch (this) {
    CapturePose.front => 'Look straight at the camera.',
    CapturePose.turnA => 'Turn your head to one side.',
    CapturePose.turnB => 'Now turn to the other side.',
    CapturePose.tiltA => 'Tilt your head up or down.',
    CapturePose.tiltB => 'Now tilt the other way.',
  };
}

/// One continuous guided capture session that snaps all 5 baseline photos
/// in sequence, each one automatically once the face is in the right pose.
///
/// Every candidate frame goes through BlazeFace (the same detector used at
/// registration) and [PoseGuide] checks framing and head pose. On Android
/// and iOS the camera streams live frames and a pose must be held briefly
/// before the photo is taken, then the photo itself is re-checked. The
/// Windows camera plugin can't stream frames, so there it takes repeated
/// still snapshots and keeps the first one in the right pose.
///
/// "Capture Now" always takes the photo as-is, as a fallback for anyone the
/// pose check struggles with; if detection stops working altogether (e.g.
/// the TensorFlow Lite library is missing), it says so and falls back to
/// manual capture only.
class GuidedFaceCapture extends StatefulWidget {
  const GuidedFaceCapture({super.key, required this.onComplete});

  /// Receives the five photos once every angle is captured. Ownership of
  /// the files passes to the caller; if the widget goes away before then,
  /// it deletes whatever it captured.
  final ValueChanged<List<File>> onComplete;

  @override
  State<GuidedFaceCapture> createState() => _GuidedFaceCaptureState();
}

class _GuidedFaceCaptureState extends State<GuidedFaceCapture> {
  bool _handedOff = false;

  static const _initAttempts = 3;

  /// How long a pose must be held on live frames before the photo is taken.
  static const _holdDuration = Duration(milliseconds: 600);

  /// Minimum gap between analysed live frames.
  static const _frameInterval = Duration(milliseconds: 120);

  /// Minimum gap between snapshots when the camera can't stream.
  static const _snapshotInterval = Duration(milliseconds: 350);

  /// Pause after each capture so the next instruction can be read.
  static const _stepCooldown = Duration(milliseconds: 800);

  /// Consecutive detection failures before pose checking is given up.
  static const _maxDetectionErrors = 3;

  CameraController? _controller;
  final FaceProcessor _faceProcessor = FaceProcessor();
  final PoseGuide _guide = PoseGuide();
  bool _isInitializing = true;
  bool _isPermissionDenied = false;
  bool _isCapturing = false;
  bool _isFinished = false;
  String? _errorMessage;

  /// Live frames (Android/iOS) or repeated snapshots (Windows).
  bool _usesStream = false;
  bool _isAnalyzing = false;
  bool _poseCheckUnavailable = false;
  bool _manualCaptureRequested = false;
  int _detectionErrors = 0;
  int _snapshotLoopId = 0;
  DateTime _lastFrameAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _pausedUntil = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime? _holdStart;
  double _holdProgress = 0;
  FaceObservation? _lastObservation;
  String _hint = 'Position your face in the frame';

  final List<CapturePose> _steps = CapturePose.values;
  int _stepIndex = 0;
  final List<File> _captured = [];
  bool _isComplete = false;

  CapturePose get _currentStep => _steps[_stepIndex];

  bool get _isActive => mounted && !_isFinished && !_isComplete;

  bool get _isPaused => DateTime.now().isBefore(_pausedUntil);

  bool get _requiresRuntimePermission =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    // Load the face models while the camera starts; failures resurface
    // (and are handled) on the first detection call.
    _faceProcessor.loadModels().then<void>(
      (_) {},
      onError: (Object e) {
        debugPrint('Face models failed to preload: $e');
      },
    );
    if (_requiresRuntimePermission) {
      unawaited(_requestPermissionThenInit());
    } else {
      unawaited(_initializeCamera());
    }
  }

  Future<void> _requestPermissionThenInit() async {
    final status = await Permission.camera.request();
    if (!mounted) {
      return;
    }
    if (status.isGranted) {
      await _initializeCamera();
    } else {
      setState(() {
        _isInitializing = false;
        _isPermissionDenied = true;
        _errorMessage = 'Camera permission is required for guided capture.';
      });
    }
  }

  Future<void> _initializeCamera() async {
    setState(() {
      _isInitializing = true;
      _errorMessage = null;
    });

    Object? lastError;
    // A webcam that another controller (the kiosk scanner, a previous
    // capture dialog) has only just released can briefly refuse to start
    // on Windows ("A device attached to the system is not functioning"),
    // so retry a few times before surfacing the error.
    for (var attempt = 0; attempt < _initAttempts; attempt++) {
      if (attempt > 0) {
        await Future.delayed(Duration(milliseconds: 700 * attempt));
        if (!mounted) {
          return;
        }
      }

      CameraController? controller;
      try {
        final cameras = await availableCameras();
        if (cameras.isEmpty) {
          throw StateError('No camera was found on this device.');
        }

        final preferred = cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.front,
          orElse: () => cameras.first,
        );

        controller = CameraController(
          preferred,
          ResolutionPreset.medium,
          enableAudio: false,
        );
        await controller.initialize();

        if (!mounted) {
          await controller.dispose();
          return;
        }

        final usesStream = controller.supportsImageStreaming();
        setState(() {
          _controller = controller;
          _usesStream = usesStream;
          _isInitializing = false;
        });

        _startPoseDetection();
        return;
      } catch (e) {
        lastError = e;
        debugPrint(
          'Guided capture camera init attempt ${attempt + 1} failed: $e',
        );
        // If the controller was constructed but initialize() (or anything
        // after it) failed, it's not wired to _controller yet, so nothing
        // else will ever dispose it — do that here, otherwise every retry
        // leaks another native camera session.
        try {
          await controller?.dispose();
        } catch (disposeError) {
          debugPrint('Error disposing failed camera controller: $disposeError');
        }
        if (e is StateError) {
          break;
        }
      }
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _isInitializing = false;
      _errorMessage = _describeCameraError(lastError);
    });
  }

  String _describeCameraError(Object? error) {
    if (error is StateError) {
      return error.message;
    }
    if (error is CameraException) {
      final description = error.description ?? '';
      if (description.contains('not functioning') ||
          description.toLowerCase().contains('in use')) {
        return 'The camera is busy or not responding.\n'
            'Close any other app using the webcam (Camera, Teams, Zoom, OBS, '
            'browser tabs) and try again. If you hot-restarted the app, stop '
            'and relaunch it — hot restart does not release the webcam.\n\n'
            'Details: ${error.code}: $description';
      }
      return 'Camera preview could not start.\n'
          'Details: ${error.code}: $description';
    }
    return 'Camera preview could not start.\nDetails: $error';
  }

  void _startPoseDetection() {
    if (_poseCheckUnavailable) {
      return;
    }
    if (_usesStream) {
      unawaited(_startStream());
    } else {
      unawaited(_runSnapshotLoop());
    }
  }

  // -- Live frames (Android / iOS) -------------------------------------------

  Future<void> _startStream() async {
    final controller = _controller;
    if (controller == null ||
        !_usesStream ||
        _poseCheckUnavailable ||
        !_isActive ||
        controller.value.isStreamingImages) {
      return;
    }
    try {
      await controller.startImageStream(_onFrame);
    } catch (e) {
      debugPrint('Could not start the camera stream: $e');
      _disablePoseCheck();
    }
  }

  Future<void> _stopStream() async {
    final controller = _controller;
    if (controller == null || !controller.value.isStreamingImages) {
      return;
    }
    try {
      await controller.stopImageStream();
    } catch (e) {
      debugPrint('Could not stop the camera stream: $e');
    }
  }

  void _onFrame(CameraImage image) {
    final controller = _controller;
    if (controller == null ||
        _isAnalyzing ||
        _isCapturing ||
        _isPaused ||
        !_isActive) {
      return;
    }
    final now = DateTime.now();
    if (now.difference(_lastFrameAt) < _frameInterval) {
      return;
    }
    _lastFrameAt = now;
    _isAnalyzing = true;
    unawaited(_analyzeFrame(image, controller));
  }

  Future<void> _analyzeFrame(
    CameraImage image,
    CameraController controller,
  ) async {
    try {
      final face = await _faceProcessor.detectCameraImage(
        image,
        rotationDegrees: cameraRotationCompensation(controller),
      );
      _detectionErrors = 0;
      if (!_isActive || _isCapturing) {
        return;
      }
      _lastObservation = face;
      final check = _guide.check(_currentStep, face);
      if (!check.ok) {
        _resetHold(check.hint);
        return;
      }
      final now = DateTime.now();
      final held = now.difference(_holdStart ??= now);
      setState(() {
        _hint = check.hint;
        _holdProgress = (held.inMilliseconds / _holdDuration.inMilliseconds)
            .clamp(0, 1);
      });
      if (held >= _holdDuration) {
        unawaited(_captureStill(trigger: face));
      }
    } catch (e) {
      _onDetectionError(e);
    } finally {
      _isAnalyzing = false;
    }
  }

  /// Takes the photo for the current step. Unless [manual], the photo is
  /// re-checked and discarded if the person moved out of the pose.
  /// [trigger] is the live-frame observation that led to the capture; it's
  /// what [PoseGuide.record] learns from, since stills may be mirrored
  /// relative to live frames.
  Future<void> _captureStill({
    FaceObservation? trigger,
    bool manual = false,
  }) async {
    final controller = _controller;
    if (_isCapturing ||
        !_isActive ||
        controller == null ||
        !controller.value.isInitialized) {
      return;
    }

    setState(() => _isCapturing = true);
    try {
      await _stopStream();
      final shot = await controller.takePicture();
      if (!manual) {
        FaceObservation? still;
        try {
          still = await _faceProcessor.detectEncodedImage(
            await shot.readAsBytes(),
          );
        } catch (e) {
          debugPrint('Could not re-check the captured photo: $e');
        }
        if (!_isActive) {
          unawaited(deleteCapturedFile(shot.path));
          return;
        }
        final verify = _guide.check(_currentStep, still, ignoreDirection: true);
        if (!verify.ok) {
          unawaited(deleteCapturedFile(shot.path));
          setState(() {
            _isCapturing = false;
            _holdStart = null;
            _holdProgress = 0;
            _hint = verify.hint;
          });
          unawaited(_startStream());
          return;
        }
      }
      if (!_isActive) {
        unawaited(deleteCapturedFile(shot.path));
        return;
      }
      await _acceptCapture(File(shot.path), trigger);
    } catch (e) {
      debugPrint('Guided capture step failed: $e');
      if (mounted) {
        setState(() => _isCapturing = false);
        unawaited(_startStream());
      }
    }
  }

  // -- Snapshots (Windows) ---------------------------------------------------

  Future<void> _runSnapshotLoop() async {
    final loopId = ++_snapshotLoopId;
    while (loopId == _snapshotLoopId && _isActive && !_poseCheckUnavailable) {
      final started = DateTime.now();
      if (!_isPaused) {
        await _takeSnapshot();
      }
      final rest = _snapshotInterval - DateTime.now().difference(started);
      if (rest > Duration.zero) {
        await Future<void>.delayed(rest);
      }
    }
  }

  Future<void> _takeSnapshot() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        controller.value.isTakingPicture ||
        _isCapturing) {
      return;
    }

    final XFile shot;
    try {
      shot = await controller.takePicture();
    } catch (e) {
      debugPrint('Snapshot failed: $e');
      return;
    }
    final manual = _manualCaptureRequested;
    _manualCaptureRequested = false;

    FaceObservation? face;
    var detected = false;
    try {
      face = await _faceProcessor.detectEncodedImage(await shot.readAsBytes());
      detected = true;
      _detectionErrors = 0;
    } catch (e) {
      _onDetectionError(e);
    }

    if (!_isActive) {
      unawaited(deleteCapturedFile(shot.path));
      return;
    }
    if (manual) {
      await _acceptCapture(File(shot.path), face);
      return;
    }
    if (!detected) {
      unawaited(deleteCapturedFile(shot.path));
      return;
    }
    final check = _guide.check(_currentStep, face);
    if (!check.ok) {
      unawaited(deleteCapturedFile(shot.path));
      _resetHold(check.hint);
      return;
    }
    await _acceptCapture(File(shot.path), face);
  }

  // -- Shared ----------------------------------------------------------------

  void _resetHold(String hint) {
    if (!mounted) {
      return;
    }
    setState(() {
      _hint = hint;
      _holdStart = null;
      _holdProgress = 0;
    });
  }

  Future<void> _acceptCapture(File file, FaceObservation? face) async {
    _guide.record(_currentStep, face);
    _captured.add(file);
    HapticFeedback.mediumImpact();

    if (_stepIndex == _steps.length - 1) {
      setState(() {
        _isComplete = true;
        _isCapturing = false;
      });
      await Future.delayed(const Duration(milliseconds: 1400));
      _finish();
      return;
    }

    _pausedUntil = DateTime.now().add(_stepCooldown);
    setState(() {
      _stepIndex += 1;
      _isCapturing = false;
      _holdStart = null;
      _holdProgress = 0;
      _lastObservation = null;
      _hint = _poseCheckUnavailable ? _manualOnlyHint : 'Nice! Next pose';
    });
    unawaited(_startStream());
  }

  static const _manualOnlyHint =
      'Automatic pose check is unavailable. Use Capture Now for each angle.';

  void _onDetectionError(Object error) {
    debugPrint('Pose detection failed: $error');
    _detectionErrors += 1;
    if (_detectionErrors >= _maxDetectionErrors) {
      _disablePoseCheck();
    }
  }

  void _disablePoseCheck() {
    if (_poseCheckUnavailable) {
      return;
    }
    _poseCheckUnavailable = true;
    _snapshotLoopId += 1;
    unawaited(_stopStream());
    _resetHold(_manualOnlyHint);
  }

  void _captureNow() {
    if (_isCapturing || !_isActive) {
      return;
    }
    if (!_usesStream && !_poseCheckUnavailable) {
      // The snapshot loop owns the camera; have it keep its next shot.
      _pausedUntil = DateTime.fromMillisecondsSinceEpoch(0);
      setState(() {
        _manualCaptureRequested = true;
        _hint = 'Capturing...';
      });
      return;
    }
    unawaited(_captureStill(trigger: _lastObservation, manual: true));
  }

  void _finish() {
    _isFinished = true;
    _snapshotLoopId += 1;
    if (mounted) {
      _handedOff = true;
      widget.onComplete(List<File>.from(_captured));
    }
  }

  @override
  void dispose() {
    _isFinished = true;
    _snapshotLoopId += 1;
    if (!_handedOff) {
      for (final file in _captured) {
        unawaited(deleteCapturedFile(file.path));
      }
    }
    _controller?.dispose();
    _faceProcessor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = InsightColors.label.resolveFrom(context);
    final secondary = InsightColors.secondaryLabel.resolveFrom(context);
    final success = InsightColors.success.resolveFrom(context);
    final accent = InsightColors.accent.resolveFrom(context);

    final String subtitle;
    if (_errorMessage != null) {
      subtitle = 'The camera needs attention before capture can start.';
    } else if (_poseCheckUnavailable) {
      subtitle = _manualOnlyHint;
    } else {
      subtitle = 'Each photo is taken automatically when the pose is right.';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _isComplete
              ? 'All Angles Captured'
              : 'Step ${_stepIndex + 1} of ${_steps.length}',
          style: InsightText.footnote.copyWith(
            color: secondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _isComplete ? 'Looking good.' : _currentStep.instruction,
          style: InsightText.title2.copyWith(color: label),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: InsightText.subheadline.copyWith(color: secondary),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            for (var i = 0; i < _steps.length; i++)
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  height: 5,
                  decoration: BoxDecoration(
                    color: i < _captured.length
                        ? success
                        : i == _stepIndex
                        ? accent
                        : InsightColors.fill.resolveFrom(context),
                    borderRadius: BorderRadius.circular(InsightRadii.capsule),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(InsightRadii.card + 6),
            child: ColoredBox(
              color: const Color(0xFF0A0A0C),
              child: _buildWell(success),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: CupertinoButton.tinted(
            sizeStyle: CupertinoButtonSize.medium,
            borderRadius: BorderRadius.circular(InsightRadii.capsule),
            onPressed:
                _isInitializing ||
                    _isCapturing ||
                    _isComplete ||
                    _manualCaptureRequested ||
                    _controller == null
                ? null
                : _captureNow,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CupertinoIcons.camera_fill, size: 18),
                SizedBox(width: 8),
                Text('Capture Now'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWell(Color success) {
    const white = CupertinoColors.white;
    const muted = Color(0x99EBEBF5);

    if (_isComplete) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.checkmark_circle_fill,
              size: 72,
              color: success,
            ),
            const SizedBox(height: 10),
            Text(
              'All 5 angles captured',
              style: InsightText.headline.copyWith(color: white),
            ),
          ],
        ),
      );
    }
    if (_isInitializing) {
      return const Center(
        child: CupertinoActivityIndicator(radius: 14, color: white),
      );
    }
    if (_errorMessage != null) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(CupertinoIcons.video_camera, size: 44, color: muted),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: InsightText.subheadline.copyWith(color: white),
              ),
              const SizedBox(height: 16),
              CupertinoButton.filled(
                sizeStyle: CupertinoButtonSize.medium,
                borderRadius: BorderRadius.circular(InsightRadii.capsule),
                onPressed: _isPermissionDenied
                    ? _requestPermissionThenInit
                    : _initializeCamera,
                child: Text(_isPermissionDenied ? 'Allow Camera' : 'Try Again'),
              ),
            ],
          ),
        ),
      );
    }
    final preview = _controller;
    if (preview == null || !preview.value.isInitialized) {
      return Center(
        child: Text(
          'Camera preview unavailable.',
          style: InsightText.subheadline.copyWith(color: white),
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        CoverCameraPreview(controller: preview),
        if (!_isCapturing)
          Positioned(
            left: 16,
            right: 16,
            bottom: 18,
            child: Center(
              child: _PoseHintCapsule(hint: _hint, holdProgress: _holdProgress),
            ),
          ),
      ],
    );
  }
}

/// Live guidance over the capture preview: what to do next, with a ring
/// that fills while a correct pose is being held.
class _PoseHintCapsule extends StatelessWidget {
  const _PoseHintCapsule({required this.hint, required this.holdProgress});

  final String hint;
  final double holdProgress;

  @override
  Widget build(BuildContext context) {
    final holding = holdProgress > 0;
    final green = CupertinoColors.systemGreen.darkColor;
    return CupertinoTheme(
      data: const CupertinoThemeData(brightness: Brightness.dark),
      child: LiquidGlass(
        clear: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(
                dimension: 20,
                child: holding
                    ? ProgressRing(
                        progress: holdProgress,
                        color: green,
                        size: 20,
                        strokeWidth: 3,
                      )
                    : const Icon(
                        CupertinoIcons.person_crop_circle,
                        size: 20,
                        color: CupertinoColors.white,
                      ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  hint,
                  textAlign: TextAlign.center,
                  style: InsightText.headline.copyWith(
                    color: CupertinoColors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
