import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';
import 'package:image_picker/image_picker.dart';
import '../models/student.dart';
import '../providers/hive_provider.dart';
import '../services/face_processor.dart';

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

  Future<void> _pickImage(ImageSource source) async {
    if (_photos.length >= 5 || _isProcessing) {
      return;
    }

    try {
      if (source == ImageSource.camera &&
          defaultTargetPlatform == TargetPlatform.windows) {
        final captured = await _showWindowsCaptureDialog();
        if (captured != null && mounted) {
          setState(() {
            _photos.add(captured);
            _feedbackIsError = false;
            _feedbackMessage = null;
          });
        }
        return;
      }

      final image = await _picker.pickImage(
        source: source,
        imageQuality: 90,
        preferredCameraDevice: CameraDevice.front,
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
        _feedbackMessage = 'Unable to capture a photo right now. Details: $e';
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Capture failed: $e')));
    }
  }

  Future<File?> _showWindowsCaptureDialog() {
    return showDialog<File>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _WindowsPhotoCaptureDialog(),
    );
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
    final scheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;

        return Form(
          key: _formKey,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header & Step Progress
                Row(
                  children: [
                    Icon(Icons.person_add_rounded, size: 20, color: scheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Student Registration',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$photoCount/5 Photos',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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
                      child: FilledButton.tonalIcon(
                        onPressed: photoCount < 5 && !_isProcessing
                            ? () => _pickImage(ImageSource.camera)
                            : null,
                        icon: const Icon(Icons.camera_alt_outlined, size: 16),
                        label: const Text('Camera'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: photoCount < 5 && !_isProcessing
                            ? () => _pickImage(ImageSource.gallery)
                            : null,
                        icon: const Icon(Icons.photo_library_outlined, size: 16),
                        label: const Text('Gallery'),
                      ),
                    ),
                    if (photoCount > 0) ...[
                      const SizedBox(width: 6),
                      IconButton(
                        onPressed: _isProcessing ? null : _clearPhotos,
                        tooltip: 'Reset Photos',
                        icon: const Icon(Icons.refresh_rounded, size: 18),
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
                      color: _feedbackIsError
                          ? scheme.errorContainer
                          : scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _feedbackIsError ? Icons.error_outline : Icons.check_circle_outline,
                          color: _feedbackIsError ? scheme.onErrorContainer : scheme.onPrimaryContainer,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _feedbackMessage!,
                            style: TextStyle(
                              color: _feedbackIsError ? scheme.onErrorContainer : scheme.onPrimaryContainer,
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
                  error: (error, stack) => Text('Error: $error', style: const TextStyle(color: Colors.red)),
                  data: (studentsBox) {
                    return SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: FilledButton.icon(
                        onPressed: isReady && !_isProcessing
                            ? () => _registerStudent(studentsBox)
                            : null,
                        icon: _isProcessing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.fingerprint_rounded, size: 18),
                        label: Text(
                          _isProcessing
                              ? 'Saving Biometric Profile...'
                              : isReady
                                  ? 'Register Student'
                                  : 'Complete ID, Name & 5 Photos to Register',
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
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
    return TextFormField(
      controller: controller,
      onChanged: onChanged,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 18),
        filled: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
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
    'Front (0°)',
    'Left (45°)',
    'Right (45°)',
    'Tilt Up',
    'Tilt Down',
  ];

  @override
  Widget build(BuildContext context) {
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
                      color: const Color(0xFF141723),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: hasPhoto
                            ? const Color(0xFF34D399)
                            : const Color(0xFF262C3E),
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
                                  color: const Color(0xFF4A5268),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '#${index + 1}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF64748B),
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
                      color: hasPhoto ? const Color(0xFF34D399) : const Color(0xFF64748B),
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

class _WindowsPhotoCaptureDialog extends StatefulWidget {
  const _WindowsPhotoCaptureDialog();

  @override
  State<_WindowsPhotoCaptureDialog> createState() =>
      _WindowsPhotoCaptureDialogState();
}

class _WindowsPhotoCaptureDialogState
    extends State<_WindowsPhotoCaptureDialog> {
  CameraController? _controller;
  bool _isInitializing = true;
  bool _isCapturing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    unawaited(_initializeCamera());
  }

  Future<void> _initializeCamera() async {
    if (mounted) {
      setState(() {
        _isInitializing = true;
        _errorMessage = null;
      });
    }

    final oldController = _controller;
    _controller = null;
    if (oldController != null) {
      try {
        await oldController.dispose();
      } catch (e) {
        debugPrint('Error disposing existing camera controller: $e');
      }
    }

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
        _errorMessage = null;
      });
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

  Future<void> _capturePhoto() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _isCapturing) {
      return;
    }

    try {
      setState(() => _isCapturing = true);
      final photo = await controller.takePicture();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(File(photo.path));
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isCapturing = false;
        _errorMessage = 'Photo capture failed. Details: $e';
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final preview = _controller;

    return Dialog(
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
              const Text(
                'Biometric Photo Capture',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Align student face inside the frame. Maintain neutral expression and adequate lighting.',
                style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: ColoredBox(
                    color: Colors.black,
                    child: Center(
                      child: _isInitializing
                          ? const CircularProgressIndicator(color: Color(0xFF6366F1))
                          : _errorMessage != null
                          ? Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white),
                              ),
                            )
                          : preview == null || !preview.value.isInitialized
                          ? const Text(
                              'Camera preview unavailable.',
                              style: TextStyle(color: Colors.white),
                            )
                          : AspectRatio(
                              aspectRatio: preview.value.aspectRatio,
                              child: CameraPreview(preview),
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
                    onPressed: _isCapturing
                        ? null
                        : () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(foregroundColor: const Color(0xFF94A3B8)),
                    child: const Text('Cancel'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _isCapturing ? null : _initializeCamera,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFCBD5E1),
                      side: const BorderSide(color: Color(0xFF272F44)),
                    ),
                    icon: const Icon(Icons.refresh_outlined, size: 16),
                    label: const Text('Retry Camera'),
                  ),
                  FilledButton.icon(
                    onPressed:
                        _isInitializing || _errorMessage != null || _isCapturing
                        ? null
                        : _capturePhoto,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: _isCapturing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.camera_alt_outlined, size: 16),
                    label: Text(
                      _isCapturing ? 'Capturing...' : 'Use This Angle',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

