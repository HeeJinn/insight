import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../models/student.dart';
import '../providers/hive_provider.dart';
import '../services/captured_file_cleanup.dart';
import '../services/face_processor.dart';
import '../ui/insight_ui.dart';
import '../widgets/guided_face_capture_io.dart';

enum _Step { details, face, saving, done }

/// Full-screen enrollment: name and ID, then the guided five-angle face
/// capture, then the face profile is built and saved. With [student] set
/// it re-enrolls that student's face and skips the details step.
class EnrollStudentScreen extends ConsumerStatefulWidget {
  const EnrollStudentScreen({super.key, this.student});

  final Student? student;

  @override
  ConsumerState<EnrollStudentScreen> createState() =>
      _EnrollStudentScreenState();
}

class _EnrollStudentScreenState extends ConsumerState<EnrollStudentScreen> {
  final _name = TextEditingController();
  final _id = TextEditingController();
  final _idFocus = FocusNode();
  late _Step _step = widget.student == null ? _Step.details : _Step.face;
  String? _detailsError;
  String? _savedName;

  bool get _reEnrolling => widget.student != null;

  @override
  void initState() {
    super.initState();
    _name.addListener(_onDetailsChanged);
    _id.addListener(_onDetailsChanged);
  }

  @override
  void dispose() {
    _name.dispose();
    _id.dispose();
    _idFocus.dispose();
    super.dispose();
  }

  void _onDetailsChanged() {
    setState(() => _detailsError = null);
  }

  bool get _detailsReady =>
      _name.text.trim().isNotEmpty && _id.text.trim().isNotEmpty;

  Future<void> _continueFromDetails() async {
    if (!_detailsReady) return;
    final box = await ref.read(studentsBoxProvider.future);
    final id = _id.text.trim();
    if (box.containsKey(id)) {
      HapticFeedback.heavyImpact();
      setState(
        () => _detailsError = 'A student with ID $id is already enrolled.',
      );
      return;
    }
    setState(() => _step = _Step.face);
  }

  /// Builds the face profile from [photos] and saves the student. Photos
  /// the guided capture took are temporary and deleted afterwards; photos
  /// picked from disk ([ownsPhotos] false) belong to the user and are left
  /// alone.
  Future<void> _save(List<File> photos, {bool ownsPhotos = true}) async {
    setState(() => _step = _Step.saving);
    final processor = FaceProcessor();
    try {
      final embeddings = await processor.processBaselinePhotos(photos);
      final existing = widget.student;
      if (existing != null) {
        existing.embeddings = embeddings;
        await existing.save();
        _savedName = existing.name;
      } else {
        final box = await ref.read(studentsBoxProvider.future);
        final student = Student(
          id: _id.text.trim(),
          name: _name.text.trim(),
          embeddings: embeddings,
        );
        await box.put(student.id, student);
        _savedName = student.name;
      }
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() => _step = _Step.done);
    } catch (e) {
      if (!mounted) return;
      setState(() => _step = _Step.face);
      await _alert(
        "Couldn't Create Face Profile",
        e is StateError ? e.message : 'Try capturing the photos again.',
      );
    } finally {
      processor.dispose();
      if (ownsPhotos) {
        for (final photo in photos) {
          unawaited(deleteCapturedFile(photo.path));
        }
      }
    }
  }

  /// Fallback when the camera can't be used: five existing photos, one per
  /// angle.
  Future<void> _choosePhotos() async {
    final picked = await ImagePicker().pickMultiImage(
      limit: 5,
      imageQuality: 90,
    );
    if (picked.isEmpty || !mounted) return;
    if (picked.length != 5) {
      await _alert(
        'Choose 5 Photos',
        'Pick one photo each: straight on, turned left, turned right, '
            'tilted up and tilted down.',
      );
      return;
    }
    await _save(picked.map((x) => File(x.path)).toList(), ownsPhotos: false);
  }

  Future<void> _alert(String title, String message) {
    return showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _close() async {
    final dirty =
        _step == _Step.face ||
        (_step == _Step.details &&
            (_name.text.isNotEmpty || _id.text.isNotEmpty));
    if (dirty && !_reEnrolling) {
      final discard = await showCupertinoModalPopup<bool>(
        context: context,
        builder: (context) => CupertinoActionSheet(
          message: const Text('This student won\'t be enrolled.'),
          actions: [
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Discard'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep Editing'),
          ),
        ),
      );
      if (discard != true) return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  void _enrollAnother() {
    _name.clear();
    _id.clear();
    setState(() {
      _savedName = null;
      _step = _Step.details;
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = _reEnrolling ? 'Re-enroll Face' : 'New Student';
    final Widget body = switch (_step) {
      _Step.details => _DetailsStep(
        name: _name,
        id: _id,
        idFocus: _idFocus,
        error: _detailsError,
        ready: _detailsReady,
        onContinue: _continueFromDetails,
      ),
      _Step.face => _FaceStep(
        studentName: widget.student?.name ?? _name.text.trim(),
        onCaptured: _save,
        onChoosePhotos: _choosePhotos,
      ),
      _Step.saving => const _SavingStep(),
      _Step.done => _DoneStep(
        name: _savedName ?? '',
        reEnrolled: _reEnrolling,
        onDone: () => Navigator.of(context).pop(),
        onEnrollAnother: _reEnrolling ? null : _enrollAnother,
      ),
    };

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _step != _Step.saving) _close();
      },
      child: CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          automaticallyImplyLeading: false,
          border: null,
          backgroundColor: const Color(0x00000000),
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 12),
          leading: _step == _Step.done || _step == _Step.saving
              ? null
              : Align(
                  widthFactor: 1,
                  child: GlassIconButton(
                    icon: CupertinoIcons.xmark,
                    semanticLabel: 'Cancel',
                    size: 40,
                    onPressed: _close,
                  ),
                ),
          middle: Text(title),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: AnimatedSwitcher(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 250),
                  child: KeyedSubtree(key: ValueKey(_step), child: body),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailsStep extends StatelessWidget {
  const _DetailsStep({
    required this.name,
    required this.id,
    required this.idFocus,
    required this.error,
    required this.ready,
    required this.onContinue,
  });

  final TextEditingController name;
  final TextEditingController id;
  final FocusNode idFocus;
  final String? error;
  final bool ready;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final secondary = InsightColors.secondaryLabel.resolveFrom(context);
    final separator = InsightColors.separator.resolveFrom(context);
    final danger = InsightColors.danger.resolveFrom(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                Center(
                  child: SymbolBadge(
                    CupertinoIcons.person_badge_plus_fill,
                    InsightColors.accent.resolveFrom(context),
                    size: 64,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Add a Student',
                  textAlign: TextAlign.center,
                  style: InsightText.title1.copyWith(
                    color: InsightColors.label.resolveFrom(context),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Next you\'ll take five quick photos of their face so the '
                  'kiosk can recognize them.',
                  textAlign: TextAlign.center,
                  style: InsightText.body.copyWith(color: secondary),
                ),
                const SizedBox(height: 28),
                ClipRSuperellipse(
                  borderRadius: BorderRadius.circular(InsightRadii.section),
                  child: ColoredBox(
                    color: InsightColors.card.resolveFrom(context),
                    child: Column(
                      children: [
                        CupertinoTextField(
                          controller: name,
                          placeholder: 'Full Name',
                          autofocus: true,
                          decoration: null,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 15,
                          ),
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.name],
                          clearButtonMode: OverlayVisibilityMode.editing,
                          onSubmitted: (_) => idFocus.requestFocus(),
                        ),
                        Container(
                          height: 0.5,
                          margin: const EdgeInsets.only(left: 16),
                          color: separator,
                        ),
                        CupertinoTextField(
                          controller: id,
                          focusNode: idFocus,
                          placeholder: 'Student ID',
                          decoration: null,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 15,
                          ),
                          autocorrect: false,
                          enableSuggestions: false,
                          textInputAction: TextInputAction.go,
                          clearButtonMode: OverlayVisibilityMode.editing,
                          onSubmitted: (_) => onContinue(),
                        ),
                      ],
                    ),
                  ),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Row(
                      children: [
                        Icon(
                          CupertinoIcons.exclamationmark_circle_fill,
                          size: 15,
                          color: danger,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            error!,
                            style: InsightText.footnote.copyWith(color: danger),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        CupertinoButton.filled(
          sizeStyle: CupertinoButtonSize.large,
          borderRadius: BorderRadius.circular(InsightRadii.capsule),
          onPressed: ready ? onContinue : null,
          child: const Text('Continue'),
        ),
      ],
    );
  }
}

class _FaceStep extends StatelessWidget {
  const _FaceStep({
    required this.studentName,
    required this.onCaptured,
    required this.onChoosePhotos,
  });

  final String studentName;
  final ValueChanged<List<File>> onCaptured;
  final VoidCallback onChoosePhotos;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: GuidedFaceCapture(onComplete: onCaptured)),
        CupertinoButton(
          onPressed: onChoosePhotos,
          child: Text(
            'Use Existing Photos Instead',
            style: InsightText.subheadline.copyWith(
              color: InsightColors.accent.resolveFrom(context),
            ),
          ),
        ),
      ],
    );
  }
}

class _SavingStep extends StatelessWidget {
  const _SavingStep();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CupertinoActivityIndicator(radius: 14),
          const SizedBox(height: 14),
          Text(
            'Creating face profile…',
            style: InsightText.headline.copyWith(
              color: InsightColors.label.resolveFrom(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'This stays on this device.',
            style: InsightText.subheadline.copyWith(
              color: InsightColors.secondaryLabel.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _DoneStep extends StatelessWidget {
  const _DoneStep({
    required this.name,
    required this.reEnrolled,
    required this.onDone,
    required this.onEnrollAnother,
  });

  final String name;
  final bool reEnrolled;
  final VoidCallback onDone;
  final VoidCallback? onEnrollAnother;

  @override
  Widget build(BuildContext context) {
    final secondary = InsightColors.secondaryLabel.resolveFrom(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  CupertinoIcons.checkmark_circle_fill,
                  size: 88,
                  color: InsightColors.success.resolveFrom(context),
                ),
                const SizedBox(height: 18),
                Text(
                  reEnrolled ? 'Face Profile Updated' : '$name Is Enrolled',
                  textAlign: TextAlign.center,
                  style: InsightText.title1.copyWith(
                    color: InsightColors.label.resolveFrom(context),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  reEnrolled
                      ? 'The kiosk will recognize $name with the new photos.'
                      : 'The kiosk will recognize them from now on.',
                  textAlign: TextAlign.center,
                  style: InsightText.body.copyWith(color: secondary),
                ),
              ],
            ),
          ),
        ),
        if (onEnrollAnother != null) ...[
          CupertinoButton.tinted(
            sizeStyle: CupertinoButtonSize.large,
            borderRadius: BorderRadius.circular(InsightRadii.capsule),
            onPressed: onEnrollAnother,
            child: const Text('Enroll Another'),
          ),
          const SizedBox(height: 10),
        ],
        CupertinoButton.filled(
          sizeStyle: CupertinoButtonSize.large,
          borderRadius: BorderRadius.circular(InsightRadii.capsule),
          onPressed: onDone,
          child: const Text('Done'),
        ),
      ],
    );
  }
}
