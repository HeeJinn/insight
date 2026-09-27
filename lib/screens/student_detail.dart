import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/attendance.dart';
import '../models/session_entry.dart';
import '../models/student.dart';
import '../providers/hive_provider.dart';
import '../providers/sessions_provider.dart';
import '../services/session_clock.dart';
import '../services/student_stats.dart';
import '../ui/insight_ui.dart';
import 'enroll_student_screen.dart';

/// A student's card: identity, face-profile status, attendance, and the
/// actions an admin takes on them. Shown beside the roster on wide windows
/// and pushed on phones (see [StudentDetailScreen]).
class StudentDetailView extends ConsumerWidget {
  const StudentDetailView({
    super.key,
    required this.student,
    this.onDeleted,
    this.topPadding = 0,
  });

  final Student student;

  /// Called after the student is deleted, so the host can clear its
  /// selection or pop.
  final VoidCallback? onDeleted;
  final double topPadding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final students = ref.watch(studentsBoxProvider).value;
    final attendance = ref.watch(attendanceBoxProvider).value;
    final sessions = ref.watch(sessionsProvider);
    if (students == null || attendance == null) return const SizedBox.expand();

    // Rebuild when this student is renamed or re-enrolled, or when a new
    // check-in arrives.
    return StreamBuilder(
      stream: students.watch(key: student.key),
      builder: (context, _) => StreamBuilder(
        stream: attendance.watch(),
        builder: (context, _) => _DetailBody(
          student: student,
          stats: StudentStats.of(student.id, attendance.values),
          sessionsByTitle: {for (final s in sessions) s.title: s},
          onDeleted: onDeleted,
          topPadding: topPadding,
        ),
      ),
    );
  }
}

/// The phone presentation: the detail pushed with a glass back button.
class StudentDetailScreen extends StatelessWidget {
  const StudentDetailScreen({super.key, required this.student});

  final Student student;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      // Like a Contacts card, the name lives in the content, not the bar.
      navigationBar: insightPushedBar(title: ''),
      child: StudentDetailView(
        student: student,
        topPadding: MediaQuery.paddingOf(context).top + 44,
        onDeleted: () => Navigator.of(context).pop(),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.student,
    required this.stats,
    required this.sessionsByTitle,
    required this.onDeleted,
    required this.topPadding,
  });

  final Student student;
  final StudentStats stats;
  final Map<String, SessionEntry> sessionsByTitle;
  final VoidCallback? onDeleted;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    final label = InsightColors.label.resolveFrom(context);
    final secondary = InsightColors.secondaryLabel.resolveFrom(context);
    final status = faceProfileStatus(student);
    final recent = stats.records.take(10).toList();

    return ListView(
      padding: EdgeInsets.fromLTRB(
        0,
        topPadding + 24,
        0,
        // On phones the bottom padding includes the floating tab bar.
        MediaQuery.paddingOf(context).bottom + 32,
      ),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: InitialsAvatar(name: student.name, size: 96)),
                const SizedBox(height: 14),
                Text(
                  student.name,
                  textAlign: TextAlign.center,
                  style: InsightText.title1.copyWith(color: label),
                ),
                const SizedBox(height: 2),
                Text(
                  'ID ${student.id}',
                  textAlign: TextAlign.center,
                  style: InsightText.subheadline.copyWith(
                    color: secondary,
                    fontFeatures: InsightText.tabular,
                  ),
                ),
                const SizedBox(height: 10),
                Center(child: _FaceStatusPill(status: status)),
                if (status != FaceProfileStatus.ready)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                    child: _ReEnrollCallout(student: student, status: status),
                  ),
                _StatsBlock(stats: stats),
                InsightListSection(
                  header: 'Recent Check-ins',
                  dividerInset: 16,
                  children: recent.isEmpty
                      ? const [
                          InsightRow(
                            title: 'No check-ins yet',
                            subtitle:
                                'They appear here after the kiosk '
                                'recognizes this student.',
                          ),
                        ]
                      : [
                          for (final r in recent)
                            _CheckInRow(
                              record: r,
                              sessionsByTitle: sessionsByTitle,
                            ),
                        ],
                ),
                InsightListSection(
                  header: 'Manage',
                  children: [
                    InsightRow(
                      leading: SymbolBadge(
                        CupertinoIcons.pencil,
                        CupertinoColors.systemGrey.resolveFrom(context),
                      ),
                      title: 'Edit Name',
                      onTap: () => _editName(context),
                    ),
                    InsightRow(
                      leading: SymbolBadge(
                        CupertinoIcons.camera_fill,
                        InsightColors.accent.resolveFrom(context),
                      ),
                      title: 'Re-enroll Face',
                      subtitle: 'Take new photos if recognition struggles.',
                      onTap: () => showEnrollStudent(context, student: student),
                    ),
                  ],
                ),
                InsightListSection(
                  footer:
                      'Deleting removes the face profile. Past check-ins stay '
                      'in attendance records.',
                  children: [
                    _DestructiveRow(
                      label: 'Delete Student',
                      onTap: () => _confirmDelete(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _editName(BuildContext context) async {
    final controller = TextEditingController(text: student.name);
    final saved = await showCupertinoDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Edit Name'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            autofocus: true,
            placeholder: 'Full Name',
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            clearButtonMode: OverlayVisibilityMode.editing,
            onSubmitted: (_) => Navigator.of(context).pop(true),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    final name = controller.text.trim();
    controller.dispose();
    if (saved == true && name.isNotEmpty && name != student.name) {
      student.name = name;
      await student.save();
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text('Delete ${student.name}?'),
        message: const Text(
          'The kiosk will stop recognizing them. Past check-ins stay in '
          'attendance records.',
        ),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete Student'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (confirmed != true) return;
    HapticFeedback.mediumImpact();
    onDeleted?.call();
    await student.delete();
  }
}

class _FaceStatusPill extends StatelessWidget {
  const _FaceStatusPill({required this.status});

  final FaceProfileStatus status;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      FaceProfileStatus.ready => StatusPill(
        label: 'Face profile ready',
        icon: CupertinoIcons.checkmark_seal_fill,
        color: InsightColors.success.resolveFrom(context),
      ),
      FaceProfileStatus.needsReEnrollment => StatusPill(
        label: 'Needs re-enrollment',
        icon: CupertinoIcons.exclamationmark_triangle_fill,
        color: InsightColors.warning.resolveFrom(context),
      ),
      FaceProfileStatus.missing => StatusPill(
        label: 'No face profile',
        icon: CupertinoIcons.person_crop_circle_badge_exclam,
        color: InsightColors.danger.resolveFrom(context),
      ),
    };
  }
}

class _ReEnrollCallout extends StatelessWidget {
  const _ReEnrollCallout({required this.student, required this.status});

  final Student student;
  final FaceProfileStatus status;

  @override
  Widget build(BuildContext context) {
    final warning = InsightColors.warning.resolveFrom(context);
    return InsightCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Icon(CupertinoIcons.exclamationmark_triangle_fill, color: warning),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              status == FaceProfileStatus.missing
                  ? "The kiosk can't recognize this student until their face "
                        'is enrolled.'
                  : 'This profile was made with an older face model. Enroll '
                        'again so the kiosk can recognize them.',
              style: InsightText.subheadline.copyWith(
                color: InsightColors.label.resolveFrom(context),
              ),
            ),
          ),
          const SizedBox(width: 12),
          CupertinoButton.filled(
            sizeStyle: CupertinoButtonSize.small,
            borderRadius: BorderRadius.circular(InsightRadii.capsule),
            onPressed: () => showEnrollStudent(context, student: student),
            child: const Text('Enroll'),
          ),
        ],
      ),
    );
  }
}

class _CheckInRow extends StatelessWidget {
  const _CheckInRow({required this.record, required this.sessionsByTitle});

  final Attendance record;
  final Map<String, SessionEntry> sessionsByTitle;

  @override
  Widget build(BuildContext context) {
    final session = sessionsByTitle[record.sessionTitle];
    final late = session != null && isLateFor(session, record.timestamp);
    return InsightRow(
      title: formatLastSeen(record.timestamp, DateTime.now()).split(',').first,
      subtitle: record.sessionTitle ?? 'General check-in',
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatClock(record.timestamp),
            style: InsightText.body.copyWith(
              color: InsightColors.secondaryLabel.resolveFrom(context),
              fontFeatures: InsightText.tabular,
            ),
          ),
          if (late)
            Text(
              'Late',
              style: InsightText.footnote.copyWith(
                color: InsightColors.warning.resolveFrom(context),
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}

class _DestructiveRow extends StatelessWidget {
  const _DestructiveRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(vertical: 14),
      onPressed: onTap,
      child: Text(
        label,
        style: InsightText.body.copyWith(
          color: InsightColors.danger.resolveFrom(context),
        ),
      ),
    );
  }
}

/// Last seen, days present and total check-ins: three tiles where there's
/// room, a Contacts-style list on narrow phones.
class _StatsBlock extends StatelessWidget {
  const _StatsBlock({required this.stats});

  final StudentStats stats;

  @override
  Widget build(BuildContext context) {
    final lastSeenDay = stats.lastSeen == null
        ? '–'
        : formatLastSeen(stats.lastSeen, stats.now).split(',').first;
    final accent = InsightColors.accent.resolveFrom(context);
    final success = InsightColors.success.resolveFrom(context);
    final purple = CupertinoColors.systemPurple.resolveFrom(context);

    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 520) {
          return InsightListSection(
            children: [
              InsightRow(
                leading: SymbolBadge(CupertinoIcons.eye_fill, accent),
                title: 'Last Seen',
                value: stats.lastSeen == null
                    ? 'Never'
                    : formatLastSeen(stats.lastSeen, stats.now),
              ),
              InsightRow(
                leading: SymbolBadge(CupertinoIcons.calendar, success),
                title: 'Days Present',
                subtitle: 'Last 30 days',
                value: '${stats.daysPresentInLast(30)}',
              ),
              InsightRow(
                leading: SymbolBadge(
                  CupertinoIcons.checkmark_seal_fill,
                  purple,
                ),
                title: 'Check-ins',
                subtitle: 'All time',
                value: '${stats.total}',
              ),
            ],
          );
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: StatTile(
                  icon: CupertinoIcons.eye_fill,
                  color: accent,
                  value: lastSeenDay,
                  label: 'Last Seen',
                  detail: stats.lastSeen == null
                      ? 'no check-ins yet'
                      : formatClock(stats.lastSeen!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatTile(
                  icon: CupertinoIcons.calendar,
                  color: success,
                  value: '${stats.daysPresentInLast(30)}',
                  label: 'Days',
                  detail: 'present, last 30',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatTile(
                  icon: CupertinoIcons.checkmark_seal_fill,
                  color: purple,
                  value: '${stats.total}',
                  label: 'Check-ins',
                  detail: 'all time',
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
