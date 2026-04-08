import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';
import 'package:image_picker/image_picker.dart';
import '../app_theme.dart';
import '../models/student.dart';
import '../providers/hive_provider.dart';
import '../services/face_processor.dart';
import 'app_chrome.dart';
import 'responsive_utils.dart';

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
        _feedbackMessage = 'Complete the form and capture 5 photos first.';
      });
      return;
    }

    final studentId = _idController.text.trim();
    final studentName = _nameController.text.trim();

    if (studentsBox.containsKey(studentId)) {
      setState(() {
        _feedbackIsError = true;
        _feedbackMessage = 'That student ID already exists.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Student ID already exists')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _feedbackIsError = false;
      _feedbackMessage = 'Processing face samples and saving student data...';
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
        _feedbackMessage = 'Student registered successfully.';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Student registered successfully')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _feedbackIsError = true;
        _feedbackMessage =
            'Registration failed. The app switched to safe mode, but this photo set still could not be processed. Details: $e';
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final compact = AppBreakpoints.isCompact(width);
        final wide = width >= 920;
        final progress = _photos.length / 5;

        return AppPanel(
          padding: EdgeInsets.all(compact ? 20 : 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSectionHeading(
                  eyebrow: 'Enrollment flow',
                  title: 'Student Registration',
                  subtitle:
                      'Create a student profile with guided face capture and save it locally for kiosk recognition.',
                  compact: compact,
                  trailing: AppPillTag(
                    label: '${_photos.length}/5 photos',
                    backgroundColor: AppTheme.blueSoft,
                    foregroundColor: AppTheme.blue,
                  ),
                ),
                const SizedBox(height: 20),
                if (wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildDetailsCard(context, wide)),
                      const SizedBox(width: 18),
                      Expanded(child: _buildCaptureCard(context, progress)),
                    ],
                  )
                else ...[
                  _buildDetailsCard(context, wide),
                  const SizedBox(height: 16),
                  _buildCaptureCard(context, progress),
                ],
                if (_feedbackMessage != null) ...[
                  const SizedBox(height: 18),
                  AppPanel(
                    radius: 24,
                    color: _feedbackIsError
                        ? AppTheme.dangerSoft
                        : AppTheme.accentSoft,
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _feedbackMessage!,
                      style: TextStyle(
                        color: _feedbackIsError
                            ? AppTheme.danger
                            : AppTheme.accentDark,
                        fontWeight: FontWeight.w700,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                studentsAsync.when(
                  loading: () => const CircularProgressIndicator(),
                  error: (error, stack) => Text('Error: $error'),
                  data: (studentsBox) => SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing
                          ? null
                          : () => _registerStudent(studentsBox),
                      icon: _isProcessing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.person_add_alt_1_outlined),
                      label: Text(
                        _isProcessing
                            ? 'Creating biometric profile...'
                            : 'Register Student',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailsCard(BuildContext context, bool wide) {
    final fields = [
      TextFormField(
        controller: _idController,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'Student ID',
          hintText: 'Enter school ID number',
        ),
        validator: (value) => value?.trim().isEmpty ?? true ? 'Required' : null,
      ),
      TextFormField(
        controller: _nameController,
        decoration: const InputDecoration(
          labelText: 'Student name',
          hintText: 'Enter full name',
        ),
        validator: (value) => value?.trim().isEmpty ?? true ? 'Required' : null,
      ),
    ];

    return _RegistrationSection(
      title: 'Identity details',
      subtitle:
          'Add the official student information before generating the face profile.',
      accent: AppTheme.blue,
      child: wide
          ? Row(
              children: [
                Expanded(child: fields[0]),
                const SizedBox(width: 14),
                Expanded(child: fields[1]),
              ],
            )
          : Column(
              children: [fields[0], const SizedBox(height: 14), fields[1]],
            ),
    );
  }

  Widget _buildCaptureCard(BuildContext context, double progress) {
    return _RegistrationSection(
      title: 'Face capture set',
      subtitle:
          'Capture five clear samples from slightly different angles for a stronger local match profile.',
      accent: AppTheme.orange,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: AppTheme.orangeGradient,
              borderRadius: BorderRadius.circular(26),
              boxShadow: AppTheme.panelShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Capture progress',
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(color: Colors.white),
                      ),
                    ),
                    Text(
                      '${(progress * 100).round()}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 10,
                    value: progress,
                    backgroundColor: Colors.white.withValues(alpha: 0.25),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _photos.length < 5 && !_isProcessing
                          ? () => _pickImage(ImageSource.camera)
                          : null,
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.ink,
                        side: BorderSide.none,
                      ),
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: const Text('Capture Photo'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _photos.length < 5 && !_isProcessing
                          ? () => _pickImage(ImageSource.gallery)
                          : null,
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.18),
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.22),
                        ),
                      ),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Upload From Gallery'),
                    ),
                    if (_photos.isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: _isProcessing ? null : _clearPhotos,
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.18),
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.22),
                          ),
                        ),
                        icon: const Icon(Icons.refresh_outlined),
                        label: const Text('Clear All'),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_photos.isNotEmpty)
            SizedBox(
              height: 118,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _photos.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Image.file(
                          _photos[index],
                          width: 102,
                          height: 118,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 8,
                        left: 8,
                        child: AppPillTag(
                          label: '#${index + 1}',
                          backgroundColor: Colors.white.withValues(alpha: 0.94),
                          foregroundColor: AppTheme.ink,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Material(
                          color: Colors.black.withValues(alpha: 0.32),
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: _isProcessing
                                ? null
                                : () => _removePhoto(index),
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          const SizedBox(height: 16),
          AppPanel(
            radius: 24,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.all(16),
            elevated: false,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.tips_and_updates_outlined),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Best results come from one front-facing photo, two slight side angles, and two neutral expressions in even lighting.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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

      final previousController = _controller;
      setState(() {
        _controller = controller;
        _isInitializing = false;
        _errorMessage = null;
      });
      await previousController?.dispose();
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
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860, maxHeight: 660),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Capture Photo',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Use the built-in camera preview to take a new registration photo on Windows.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: ColoredBox(
                    color: Colors.black,
                    child: Center(
                      child: _isInitializing
                          ? const CircularProgressIndicator()
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
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isCapturing
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _isCapturing ? null : _initializeCamera,
                    icon: const Icon(Icons.refresh_outlined),
                    label: const Text('Retry Camera'),
                  ),
                  ElevatedButton.icon(
                    onPressed:
                        _isInitializing || _errorMessage != null || _isCapturing
                        ? null
                        : _capturePhoto,
                    icon: _isCapturing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.camera_alt_outlined),
                    label: Text(
                      _isCapturing ? 'Capturing...' : 'Use This Photo',
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

class _RegistrationSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color accent;
  final Widget child;

  const _RegistrationSection({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      radius: 28,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.widgets_outlined, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}
