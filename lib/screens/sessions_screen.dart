import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import '../app_theme.dart';
import '../core/widgets/core_widgets.dart';
import '../models/session_entry.dart';
import '../providers/sessions_provider.dart';
import '../widgets/app_chrome.dart';
import '../widgets/responsive_utils.dart';

class SessionsScreen extends ConsumerWidget {
  const SessionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(sessionsProvider);
    final now = TimeOfDay.now();
    final nowMinute = now.hour * 60 + now.minute;
    final live = sessions
        .where(
          (s) =>
              s.startMinuteOfDay <= nowMinute && s.endMinuteOfDay >= nowMinute,
        )
        .toList(growable: false);
    final upcoming = sessions
        .where((s) => s.startMinuteOfDay > nowMinute)
        .toList(growable: false);
    final archived = sessions
        .where((s) => s.endMinuteOfDay < nowMinute)
        .toList(growable: false);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: AppBackground(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final contentWidth = AppBreakpoints.contentWidth(constraints.maxWidth);
            final padding = AppBreakpoints.pagePadding(constraints.maxWidth);

            return SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: contentWidth),
                  child: ListView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: padding.copyWith(
                      bottom: AppBreakpoints.navAwareBottomInset(context),
                    ),
                    children: [
                      // Apple Large Title Header
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'SCHEDULE',
                                    style: AppleTypography.caption1.copyWith(
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.8,
                                      color: context.appColors.secondaryText,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Sessions',
                                    style: AppleTypography.largeTitle.copyWith(
                                      color: context.appColors.primaryText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                _showAddSessionDialog(context, ref);
                              },
                              icon: const Icon(Icons.add_circle_outline_rounded, size: 26),
                              color: context.appColors.blue,
                              tooltip: 'Add Session',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      if (sessions.isEmpty)
                        AppleInsetGroupedSection(
                          header: 'Timetable',
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 32,
                              ),
                              child: Center(
                                child: Column(
                                  children: [
                                    // "Empty State" by Creative Salt & Pepper,
                                    // via LottieFiles (Lottie Simple License).
                                    SizedBox(
                                      width: 120,
                                      height: 120,
                                      child: Lottie.asset(
                                        'assets/animations/empty_state.json',
                                        repeat: true,
                                        fit: BoxFit.contain,
                                        errorBuilder: (context, error, stackTrace) => Icon(
                                          Icons.calendar_month_rounded,
                                          size: 38,
                                          color: context.appColors.secondaryText,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'No Class Sessions',
                                      style: AppleTypography.headline.copyWith(
                                        color: context.appColors.primaryText,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Add class attendance windows to automate kiosk sessions.',
                                      textAlign: TextAlign.center,
                                      style: AppleTypography.subhead.copyWith(
                                        color: context.appColors.secondaryText,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    AppleTactileButton(
                                      height: 38,
                                      onPressed: () =>
                                          _showAddSessionDialog(context, ref),
                                      child: const Text('Add Session'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      else ...[
                        if (live.isNotEmpty)
                          AppleInsetGroupedSection(
                            header: 'Live Now',
                            children: live.map(
                              (session) => _SessionRow(
                                session: session,
                                isLive: true,
                                onDelete: () => ref
                                    .read(sessionsProvider.notifier)
                                    .removeSession(session.id),
                              ),
                            ).toList(),
                          ),
                        if (upcoming.isNotEmpty)
                          AppleInsetGroupedSection(
                            header: 'Upcoming Sessions',
                            children: upcoming.map(
                              (session) => _SessionRow(
                                session: session,
                                isLive: false,
                                onDelete: () => ref
                                    .read(sessionsProvider.notifier)
                                    .removeSession(session.id),
                              ),
                            ).toList(),
                          ),
                        if (archived.isNotEmpty)
                          AppleInsetGroupedSection(
                            header: 'Concluded Today',
                            children: archived.map(
                              (session) => _SessionRow(
                                session: session,
                                isLive: false,
                                onDelete: () => ref
                                    .read(sessionsProvider.notifier)
                                    .removeSession(session.id),
                              ),
                            ).toList(),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _showAddSessionDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final titleCtrl = TextEditingController();
    final roomCtrl = TextEditingController();
    final expectedCtrl = TextEditingController(text: '30');
    TimeOfDay? start = TimeOfDay.now();
    TimeOfDay? end = TimeOfDay(hour: (start.hour + 1) % 24, minute: start.minute);
    String? errorText;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return AlertDialog(
            backgroundColor: isDark
                ? context.appColors.surface
                : context.appColors.elevatedSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: context.appColors.border,
                width: 0.5,
              ),
            ),
            title: Text(
              'New Session',
              style: AppleTypography.headline.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleCtrl,
                    autofocus: true,
                    style: AppleTypography.body,
                    decoration: const InputDecoration(
                      labelText: 'Course / Session Title',
                      hintText: 'e.g. CS-301 Computer Vision',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: roomCtrl,
                          style: AppleTypography.body,
                          decoration: const InputDecoration(
                            labelText: 'Room',
                            hintText: 'Lab 4B',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: expectedCtrl,
                          keyboardType: TextInputType.number,
                          style: AppleTypography.body,
                          decoration: const InputDecoration(
                            labelText: 'Expected',
                            hintText: '30',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'ATTENDANCE WINDOW',
                    style: AppleTypography.caption1.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                      color: context.appColors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: context.appColors.border,
                              width: 0.5,
                            ),
                          ),
                          onPressed: () async {
                            final t = await showTimePicker(
                              context: context,
                              initialTime: start ?? TimeOfDay.now(),
                            );
                            if (t != null) setState(() => start = t);
                          },
                          child: Text(
                            start == null ? 'Start' : start!.format(context),
                            style: AppleTypography.footnote.copyWith(
                              fontFeatures: AppleTypography.tabular,
                            ),
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Text('–'),
                      ),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: context.appColors.border,
                              width: 0.5,
                            ),
                          ),
                          onPressed: () async {
                            final t = await showTimePicker(
                              context: context,
                              initialTime: end ?? TimeOfDay.now(),
                            );
                            if (t != null) setState(() => end = t);
                          },
                          child: Text(
                            end == null ? 'End' : end!.format(context),
                            style: AppleTypography.footnote.copyWith(
                              fontFeatures: AppleTypography.tabular,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      errorText!,
                      style: AppleTypography.footnote.copyWith(
                        color: context.appColors.danger,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: AppleTypography.callout.copyWith(
                    color: context.appColors.secondaryText,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  if (titleCtrl.text.trim().isEmpty) {
                    setState(() => errorText = 'Enter a course or session title.');
                    return;
                  }
                  if (roomCtrl.text.trim().isEmpty) {
                    setState(() => errorText = 'Enter a room.');
                    return;
                  }
                  if (start == null || end == null) {
                    setState(() => errorText = 'Set both a start and end time.');
                    return;
                  }
                  final startM = start!.hour * 60 + start!.minute;
                  final endM = end!.hour * 60 + end!.minute;
                  if (endM <= startM) {
                    setState(() => errorText = 'End time must be after the start time.');
                    return;
                  }
                  ref
                      .read(sessionsProvider.notifier)
                      .addSession(
                        SessionEntry(
                          id: DateTime.now().microsecondsSinceEpoch.toString(),
                          title: titleCtrl.text.trim(),
                          room: roomCtrl.text.trim(),
                          startMinuteOfDay: startM,
                          endMinuteOfDay: endM,
                          expected: int.tryParse(expectedCtrl.text.trim()) ?? 0,
                        ),
                      );
                  Navigator.pop(context);
                },
                child: Text(
                  'Add',
                  style: AppleTypography.callout.copyWith(
                    fontWeight: FontWeight.w700,
                    color: context.appColors.blue,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  final SessionEntry session;
  final bool isLive;
  final VoidCallback onDelete;

  const _SessionRow({
    required this.session,
    required this.isLive,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          AppIconBadge(
            icon: isLive ? Icons.sensors_rounded : Icons.schedule_rounded,
            tint: isLive ? context.appColors.success : context.appColors.blue,
            size: 32,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        session.title,
                        style: AppleTypography.body.copyWith(
                          fontWeight: FontWeight.w600,
                          color: context.appColors.primaryText,
                        ),
                      ),
                    ),
                    if (isLive) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: (context.appColors.success)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'LIVE',
                          style: AppleTypography.caption2.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: context.appColors.success,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${session.room} · ${session.expected} expected',
                  style: AppleTypography.subhead.copyWith(
                    color: context.appColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            session.timeLabel,
            style: AppleTypography.footnote.copyWith(
              fontWeight: FontWeight.w500,
              fontFeatures: AppleTypography.tabular,
              color: context.appColors.secondaryText,
            ),
          ),
          const SizedBox(width: 6),
          if (isLive) ...[
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.camera_alt_rounded, size: 18),
              color: context.appColors.success,
              onPressed: () => context.push('/kiosk'),
              tooltip: 'Start Kiosk',
            ),
          ],
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.delete_outline_rounded, size: 16),
            color: context.appColors.secondaryText,
            onPressed: () async {
              HapticFeedback.lightImpact();
              final confirmed = await AppDialog.confirm(
                context,
                title: 'Delete Session?',
                message: isLive
                    ? '"${session.title}" is currently live. Deleting it will end the active attendance window immediately.'
                    : 'This removes "${session.title}" from the schedule. This can\'t be undone.',
                confirmLabel: 'Delete',
                isDestructive: true,
              );
              if (confirmed) onDelete();
            },
            tooltip: 'Delete',
          ),
        ],
      ),
    );
  }
}
