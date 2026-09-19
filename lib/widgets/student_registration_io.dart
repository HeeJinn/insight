import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
import 'package:permission_handler/permission_handler.dart';
import '../app_theme.dart';
import '../core/widgets/core_widgets.dart';
import '../models/student.dart';
import '../providers/hive_provider.dart';
import '../services/captured_file_cleanup.dart';
import '../services/face_processor.dart';
import 'app_chrome.dart';

class StudentRegistration extends ConsumerStatefulWidget {
  const StudentRegistration({super.key});

  @override
  ConsumerState<StudentRegistration> createState() =>
      _StudentRegistrationState();
}

class _StudentRegistrationState extends ConsumerState<StudentRegistration> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _idController = TextEditingController();
  final List<File> _photos = [];
  final ImagePicker _picker = ImagePicker();
  bool _isProcessing = false;
  String? _feedbackMessage;
  bool _feedbackIsError = false;

  @override
  void dispose() {
    _nameController.dispose();
    _idController.dispose();
    super.dispose();
  }

  Future<void> _pickFromGallery() async {
    if (_photos.length >= 5 || _isProcessing) {
      return;
    }

    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (image != null && mounted) {
        setState(() {
          _photos.add(File(image.path));
          _feedbackIsError = false;
          _feedbackMessage = null;
        });
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _feedbackIsError = true;
        _feedbackMessage = 'Unable to add a photo right now. Details: $e';
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Selection failed: $e')));
    }
  }

  Future<void> _startGuidedCapture() async {
    if (_isProcessing) {
      return;
    }

    if (_photos.isNotEmpty) {
      final confirmed = await AppDialog.confirm(
        context,
        title: 'Start Guided Capture?',
        message:
            'This restarts face capture and replaces the ${_photos.length} photo(s) already added.',
        confirmLabel: 'Start Over',
      );
      if (!confirmed || !mounted) {
        return;
      }
    }

    final captured = await showDialog<List<File>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _GuidedFaceCaptureDialog(),
    );

    if (captured != null && captured.length == 5 && mounted) {
      setState(() {
        _photos
          ..clear()
          ..addAll(captured);
        _feedbackIsError = false;
        _feedbackMessage = null;
      });
    }
  }

  Future<void> _registerStudent(Box<Student> studentsBox) async {
    if (!_formKey.currentState!.validate() || _photos.length != 5) {
      setState(() {
        _feedbackIsError = true;
        _feedbackMessage = 'Complete identity details and capture all 5 face angles first.';
      });
      return;
    }

    final studentId = _idController.text.trim();
    final studentName = _nameController.text.trim();

    if (studentsBox.containsKey(studentId)) {
      setState(() {
        _feedbackIsError = true;
        _feedbackMessage = 'Student ID "$studentId" is already registered.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Student ID "$studentId" already exists')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _feedbackIsError = false;
      _feedbackMessage = 'Generating 512-d facial embeddings and saving profile...';
    });

    final faceProcessor = FaceProcessor();

    try {
      final embeddings = await faceProcessor.processBaselinePhotos(_photos);
      final student = Student(
        id: studentId,
        name: studentName,
        embeddings: embeddings,
      );

      await studentsBox.put(student.id, student);

      if (!mounted) {
        return;
      }

      _nameController.clear();
      _idController.clear();
      setState(() {
        _photos.clear();
        _feedbackIsError = false;
        _feedbackMessage = 'Student "$studentName" successfully registered with 5 biometric vectors.';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Biometric profile for "$studentName" created successfully'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _feedbackIsError = true;
        _feedbackMessage =
            'Registration failed. Could not process face embeddings. Details: $e';
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error registering student: $e')));
    } finally {
      faceProcessor.dispose();
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _photos.removeAt(index);
    });
  }

  void _clearPhotos() {
    setState(() {
      _photos.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(studentsBoxProvider);
    final photoCount = _photos.length;
    final hasId = _idController.text.trim().isNotEmpty;
    final hasName = _nameController.text.trim().isNotEmpty;
    final isReady = hasId && hasName && photoCount == 5;
    final colors = context.appColors;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;

        // No extra card wrapper here — the parent (_DashboardCardFrame)
        // already frames this in an AppleInsetGroupedSection, so adding
        // another background/border here would double-box it.
        return Form(
          key: _formKey,
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header & Step Progress
                Row(
                  children: [
                    Icon(Icons.person_add_rounded, size: 20, color: colors.accent),
                    const SizedBox(width: 8),
                    Text(
                      'Student Registration',
                      style: AppleTypography.headline.copyWith(
                        color: colors.primaryText,
                      ),
                    ),
                    const Spacer(),
                    AppPillTag(
                      label: '$photoCount/5 Photos',
                      foregroundColor: photoCount == 5 ? colors.success : colors.accent,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Form Fields
                if (wide)
                  Row(
                    children: [
                      Expanded(
                        child: _M3InputField(
                          controller: _idController,
                          label: 'Student ID',
                          hint: 'e.g. 2026-CS-0841',
                          icon: Icons.badge_outlined,
                          onChanged: (_) => setState(() {}),
                          validator: (v) =>
                              v?.trim().isEmpty ?? true ? 'Student ID is required' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _M3InputField(
                          controller: _nameController,
                          label: 'Full Name',
                          hint: 'e.g. Marcus Vance',
                          icon: Icons.person_outline,
                          onChanged: (_) => setState(() {}),
                          validator: (v) =>
                              v?.trim().isEmpty ?? true ? 'Full name is required' : null,
                        ),
                      ),
                    ],
                  )
                else ...[
                  _M3InputField(
                    controller: _idController,
                    label: 'Student ID',
                    hint: 'e.g. 2026-CS-0841',
                    icon: Icons.badge_outlined,
                    onChanged: (_) => setState(() {}),
                    validator: (v) =>
                        v?.trim().isEmpty ?? true ? 'Student ID is required' : null,
                  ),
                  const SizedBox(height: 12),
                  _M3InputField(
                    controller: _nameController,
                    label: 'Full Name',
                    hint: 'e.g. Marcus Vance',
                    icon: Icons.person_outline,
                    onChanged: (_) => setState(() {}),
                    validator: (v) =>
                        v?.trim().isEmpty ?? true ? 'Full name is required' : null,
                  ),
                ],

                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 14),

                // Face Photo Action Bar
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: photoCount < 5 && !_isProcessing
                            ? _startGuidedCapture
                            : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: colors.accent,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: colors.surface,
                          disabledForegroundColor: colors.mutedText,
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.camera_alt_outlined, size: 16),
                        label: const Text('Guided Capture'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: photoCount < 5 && !_isProcessing
                            ? _pickFromGallery
                            : null,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: colors.border),
                          foregroundColor: colors.primaryText,
                          disabledForegroundColor: colors.mutedText,
                        ),
                        icon: const Icon(Icons.photo_library_outlined, size: 16),
                        label: const Text('Gallery'),
                      ),
                    ),
                    if (photoCount > 0) ...[
                      const SizedBox(width: 6),
                      IconButton(
                        onPressed: _isProcessing ? null : _clearPhotos,
                        tooltip: 'Reset Photos',
                        icon: Icon(Icons.refresh_rounded, size: 18, color: colors.secondaryText),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),

                // 5-Slot Target Photo Grid
                _FaceAngleSlotsGrid(
                  photos: _photos,
                  onRemovePhoto: _isProcessing ? null : _removePhoto,
                ),

                // Feedback message
                if (_feedbackMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _feedbackIsError ? colors.dangerSoft : colors.successSoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        if (_feedbackIsError)
                          Icon(
                            Icons.error_outline,
                            color: colors.danger,
                            size: 16,
                          )
                        else if (_isProcessing)
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colors.success,
                            ),
                          )
                        else
                          // "Success" by Darius Afchar, via LottieFiles
                          // (Lottie Simple License).
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: Lottie.asset(
                              'assets/animations/success_checkmark.json',
                              repeat: false,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) => Icon(
                                Icons.check_circle_outline,
                                color: colors.success,
                                size: 16,
                              ),
                            ),
                          ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _feedbackMessage!,
                            style: TextStyle(
                              color: _feedbackIsError ? colors.danger : colors.success,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Submit Button
                studentsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, stack) => Text(
                    'Error: $error',
                    style: TextStyle(color: colors.danger),
                  ),
                  data: (studentsBox) {
                    return AppleTactileButton(
                      height: 44,
                      onPressed: isReady && !_isProcessing
                          ? () => _registerStudent(studentsBox)
                          : null,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isProcessing)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          else
                            const Icon(Icons.fingerprint_rounded, size: 18),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _isProcessing
                                  ? 'Saving Biometric Profile...'
                                  : isReady
                                      ? 'Register Student'
                                      : 'Complete ID, Name & 5 Photos to Register',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
        );
      },
    );
  }
}

class _M3InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;

  const _M3InputField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    // Deliberately doesn't override border/fill colors here — the app
    // theme's inputDecorationTheme (app_theme.dart) already provides the
    // correct surface fill and border/focus colors for both light and dark.
    return TextFormField(
      controller: controller,
      onChanged: onChanged,
      validator: validator,
      style: AppleTypography.body.copyWith(color: context.appColors.primaryText),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 18),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}

class _FaceAngleSlotsGrid extends StatelessWidget {
  final List<File> photos;
  final ValueChanged<int>? onRemovePhoto;

  const _FaceAngleSlotsGrid({
    required this.photos,
    required this.onRemovePhoto,
  });

  static const _slotLabels = [
    'Front',
    'Turn A',
    'Turn B',
    'Tilt A',
    'Tilt B',
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 4 * 8) / 5;
        final slotSize = itemWidth.clamp(58.0, 110.0);

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(5, (index) {
            final hasPhoto = index < photos.length;
            final file = hasPhoto ? photos[index] : null;

            return SizedBox(
              width: slotSize,
              child: Column(
                children: [
                  Container(
                    height: slotSize * 1.15,
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: hasPhoto ? colors.success : colors.border,
                        width: hasPhoto ? 1.5 : 1,
                      ),
                    ),
                    child: Stack(
                      children: [
                        if (hasPhoto && file != null) ...[
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(7),
                              child: Image.file(file, fit: BoxFit.cover),
                            ),
                          ),
                          if (onRemovePhoto != null)
                            Positioned(
                              top: 3,
                              right: 3,
                              child: GestureDetector(
                                onTap: () => onRemovePhoto!(index),
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                    color: Colors.black87,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close, size: 11, color: Colors.white),
                                ),
                              ),
                            ),
                        ] else
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_a_photo_outlined,
                                  size: 16,
                                  color: colors.mutedText,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '#${index + 1}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: colors.mutedText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _slotLabels[index],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: hasPhoto ? FontWeight.w700 : FontWeight.w500,
                      color: hasPhoto ? colors.success : colors.mutedText,
                    ),
                  ),
                ],
              ),
            );
          }),
        );
      },
    );
  }
}

enum _CaptureStep { front, turnA, turnB, tiltA, tiltB }

extension on _CaptureStep {
  String get instruction {
    switch (this) {
      case _CaptureStep.front:
        return 'Look straight at the camera and hold still.';
      case _CaptureStep.turnA:
        return 'Slowly turn your head to one side.';
      case _CaptureStep.turnB:
        return 'Now turn to the other side.';
      case _CaptureStep.tiltA:
        return 'Tilt your head up or down slightly.';
      case _CaptureStep.tiltB:
        return 'Now tilt the other way.';
    }
  }
}

/// One continuous guided capture session that automatically snaps all 5
/// baseline photos in sequence, instead of requiring 5 separate manual
/// "open dialog, click shutter" cycles.
///
/// This is a timer-guided flow, not a pose-verified one: each step shows an
/// instruction and a short countdown, then auto-captures — it doesn't check
/// that you actually moved your head. Real pose verification would need a
/// working face-landmark model, which isn't available on Windows without
/// building TensorFlow Lite's C library from source (no official prebuilt
/// exists for this platform); this flow avoids that dependency entirely so
/// it works everywhere today.
class _GuidedFaceCaptureDialog extends StatefulWidget {
  const _GuidedFaceCaptureDialog();

  @override
  State<_GuidedFaceCaptureDialog> createState() =>
      _GuidedFaceCaptureDialogState();
}

class _GuidedFaceCaptureDialogState extends State<_GuidedFaceCaptureDialog> {
  static const _countdownStart = 3;

  CameraController? _controller;
  bool _isInitializing = true;
  bool _isPermissionDenied = false;
  bool _isCapturing = false;
  bool _isFinished = false;
  String? _errorMessage;
  Timer? _countdownTimer;
  int _countdown = _countdownStart;

  final List<_CaptureStep> _steps = _CaptureStep.values;
  int _stepIndex = 0;
  final List<File> _captured = [];
  bool _isComplete = false;

  _CaptureStep get _currentStep => _steps[_stepIndex];

  bool get _requiresRuntimePermission =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
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

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw StateError('No camera was found on this device.');
      }

      final preferred = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        preferred,
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
        _isInitializing = false;
      });

      _startCountdown();
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isInitializing = false;
        _errorMessage = 'Camera preview could not start. Details: $e';
      });
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() => _countdown = _countdownStart);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _isFinished) {
        timer.cancel();
        return;
      }
      if (_countdown <= 1) {
        timer.cancel();
        unawaited(_captureStep());
        return;
      }
      setState(() => _countdown -= 1);
    });
  }

  Future<void> _captureStep() async {
    final controller = _controller;
    if (_isCapturing || controller == null || !controller.value.isInitialized) {
      return;
    }

    setState(() => _isCapturing = true);
    try {
      final shot = await controller.takePicture();
      _captured.add(File(shot.path));

      if (_stepIndex == _steps.length - 1) {
        HapticFeedback.mediumImpact();
        setState(() => _isComplete = true);
        await Future.delayed(const Duration(milliseconds: 1400));
        _finish();
        return;
      }

      HapticFeedback.mediumImpact();
      setState(() {
        _stepIndex += 1;
        _isCapturing = false;
      });
      _startCountdown();
    } catch (e) {
      debugPrint('Guided capture step failed: $e');
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }
  }

  void _captureNow() {
    _countdownTimer?.cancel();
    unawaited(_captureStep());
  }

  void _finish() {
    _isFinished = true;
    _countdownTimer?.cancel();
    if (mounted) {
      Navigator.of(context).pop(List<File>.from(_captured));
    }
  }

  void _cancel() {
    _isFinished = true;
    _countdownTimer?.cancel();
    for (final file in _captured) {
      unawaited(deleteCapturedFile(file.path));
    }
    if (mounted) {
      Navigator.of(context).pop(null);
    }
  }

  @override
  void dispose() {
    _isFinished = true;
    _countdownTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final preview = _controller;

    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: const Color(0xFF131620),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF232738)),
        ),
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860, maxHeight: 660),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Guided Face Capture',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Step ${_stepIndex + 1} of ${_steps.length}',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _isCapturing
                      ? 'Capturing...'
                      : '${_currentStep.instruction} (${_countdown}s)',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                ),
                const SizedBox(height: 12),
                Row(
                  children: List.generate(_steps.length, (index) {
                    final done = index < _stepIndex ||
                        (index == _stepIndex && _captured.length > index);
                    final active = index == _stepIndex;
                    return Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        height: 4,
                        decoration: BoxDecoration(
                          color: done
                              ? const Color(0xFF34D399)
                              : active
                                  ? const Color(0xFF6366F1)
                                  : const Color(0xFF262C3E),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: ColoredBox(
                      color: Colors.black,
                      child: Center(
                        child: _isComplete
                            ? Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // "Success" by Darius Afchar, via
                                  // LottieFiles (Lottie Simple License).
                                  SizedBox(
                                    width: 120,
                                    height: 120,
                                    child: Lottie.asset(
                                      'assets/animations/success_checkmark.json',
                                      repeat: false,
                                      fit: BoxFit.contain,
                                      errorBuilder: (context, error, stackTrace) => const Icon(
                                        Icons.check_circle_rounded,
                                        size: 72,
                                        color: Color(0xFF34D399),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'All 5 angles captured',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              )
                            : _isInitializing
                            ? const CircularProgressIndicator(color: Color(0xFF6366F1))
                            : _errorMessage != null
                                ? Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _errorMessage!,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(color: Colors.white),
                                        ),
                                        if (_isPermissionDenied) ...[
                                          const SizedBox(height: 16),
                                          OutlinedButton(
                                            onPressed: _requestPermissionThenInit,
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: const Color(0xFFCBD5E1),
                                              side: const BorderSide(color: Color(0xFF272F44)),
                                            ),
                                            child: const Text('Grant Camera Permission'),
                                          ),
                                        ],
                                      ],
                                    ),
                                  )
                                : preview == null || !preview.value.isInitialized
                                    ? const Text(
                                        'Camera preview unavailable.',
                                        style: TextStyle(color: Colors.white),
                                      )
                                    : Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          AspectRatio(
                                            aspectRatio: preview.value.aspectRatio,
                                            child: CameraPreview(preview),
                                          ),
                                          if (!_isCapturing)
                                            Positioned(
                                              bottom: 16,
                                              left: 0,
                                              right: 0,
                                              child: Center(
                                                child: Container(
                                                  width: 48,
                                                  height: 48,
                                                  alignment: Alignment.center,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: Colors.black.withValues(alpha: 0.55),
                                                    border: Border.all(color: Colors.white, width: 2),
                                                  ),
                                                  child: Text(
                                                    '$_countdown',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 20,
                                                      fontWeight: FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isComplete ? null : _cancel,
                      style: TextButton.styleFrom(foregroundColor: const Color(0xFF94A3B8)),
                      child: const Text('Cancel'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _isInitializing || _isCapturing || _isComplete ? null : _captureNow,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFCBD5E1),
                        side: const BorderSide(color: Color(0xFF272F44)),
                      ),
                      icon: const Icon(Icons.camera_alt_outlined, size: 16),
                      label: const Text('Capture Now'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
