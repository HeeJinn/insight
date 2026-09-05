import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../app_theme.dart';
import '../models/session_entry.dart';
import '../providers/sessions_provider.dart';
import '../widgets/app_chrome.dart';
import '../widgets/biometric_indicators.dart';
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
            final compact = AppBreakpoints.isCompact(constraints.maxWidth);
            return AppPageScaffold(
              eyebrow: 'TIMETABLE & KIOSK SCHEDULER',
              title: 'Sessions',
              subtitle: 'Course attendance windows and direct kiosk triggers',
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  // Action header row
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Text(
                              'Schedule timeline',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.2,
                                  ),
                            ),
                            if (live.isNotEmpty) ...[
                              const SizedBox(width: 10),
                              TelemetryBadge(
                                label: '${live.length} ACTIVE',
                                pulse: true,
                                color: context.appColors.accent,
                              ),
                            ],
                          ],
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: () => _showAddSessionDialog(context, ref),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Add session'),
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Telemetry Overview Panel
                  AppPanel(
                    radius: 16,
                    padding: const EdgeInsets.all(16),
                    showReticles: live.isNotEmpty,
                    borderColor: live.isNotEmpty
                        ? context.appColors.accent.withValues(alpha: 0.35)
                        : null,
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: live.isNotEmpty
                                ? context.appColors.accentSoft
                                : Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: live.isNotEmpty
                                  ? context.appColors.accent.withValues(alpha: 0.4)
                                  : Theme.of(context).dividerColor,
                            ),
                          ),
                          child: Icon(
                            live.isNotEmpty
                                ? Icons.sensors_rounded
                                : Icons.schedule_rounded,
                            color: live.isNotEmpty
                                ? context.appColors.accentDark
                                : context.appColors.mutedText,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                live.isNotEmpty
                                    ? 'Active Attendance Window Open'
                                    : 'All Timetabled Class Windows',
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                live.isNotEmpty
                                    ? 'Kiosk scanner will automatically tag attendance to active sessions.'
                                    : 'Launch optical scanning directly from any configured session below.',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: context.appColors.mutedText),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (sessions.isEmpty)
                    AppEmptyState(
                      icon: Icons.calendar_month_outlined,
                      title: 'No class sessions scheduled',
                      subtitle:
                          'Add a session to configure start/end windows and launch instant kiosk recognition.',
                      action: FilledButton.tonalIcon(
                        onPressed: () => _showAddSessionDialog(context, ref),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Create first session'),
                      ),
                    )
                  else ...[
                    if (live.isNotEmpty) ...[
                      _SectionHeader(
                        title: 'LIVE NOW',
                        count: live.length,
                        badgeColor: context.appColors.accent,
                        pulse: true,
                      ),
                      const SizedBox(height: 10),
                      ...live.map(
                        (session) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _SessionCard(
                            session: session,
                            isLive: true,
                            compact: compact,
                            onDelete: () => ref
                                .read(sessionsProvider.notifier)
                                .removeSession(session.id),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (upcoming.isNotEmpty) ...[
                      _SectionHeader(
                        title: 'UPCOMING SESSIONS',
                        count: upcoming.length,
                      ),
                      const SizedBox(height: 10),
                      ...upcoming.map(
                        (session) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _SessionCard(
                            session: session,
                            isLive: false,
                            compact: compact,
                            onDelete: () => ref
                                .read(sessionsProvider.notifier)
                                .removeSession(session.id),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (archived.isNotEmpty) ...[
                      _SectionHeader(
                        title: 'ARCHIVED / CONCLUDED',
                        count: archived.length,
                      ),
                      const SizedBox(height: 10),
                      ...archived.map(
                        (session) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _SessionCard(
                            session: session,
                            isLive: false,
                            compact: compact,
                            onDelete: () => ref
                                .read(sessionsProvider.notifier)
                                .removeSession(session.id),
                          ),
                        ),
                      ),
                    ],
                  ],
                  SizedBox(height: AppBreakpoints.navAwareBottomInset(context)),
                ],
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

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Theme.of(context).dividerColor),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.calendar_today_rounded,
                  size: 16,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 10),
              const Text('Add Class Session'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleCtrl,
                  autofocus: true,
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  decoration: const InputDecoration(
                    labelText: 'Course / Session title',
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
                        onTapOutside: (_) => FocusScope.of(context).unfocus(),
                        decoration: const InputDecoration(
                          labelText: 'Room / Lab',
                          hintText: 'e.g. Lab 4B',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: expectedCtrl,
                        onTapOutside: (_) => FocusScope.of(context).unfocus(),
                        keyboardType: TextInputType.number,
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
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    letterSpacing: 1.0,
                    fontWeight: FontWeight.w700,
                    color: context.appColors.mutedText,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final t = await showTimePicker(
                            context: context,
                            initialTime: start ?? TimeOfDay.now(),
                          );
                          if (t != null) setState(() => start = t);
                        },
                        icon: const Icon(Icons.access_time_rounded, size: 16),
                        label: Text(
                          start == null ? 'Start' : start!.format(context),
                          style: const TextStyle(
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Text('→'),
                    ),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final t = await showTimePicker(
                            context: context,
                            initialTime: end ?? TimeOfDay.now(),
                          );
                          if (t != null) setState(() => end = t);
                        },
                        icon: const Icon(Icons.access_time_rounded, size: 16),
                        label: Text(
                          end == null ? 'End' : end!.format(context),
                          style: const TextStyle(
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (titleCtrl.text.trim().isEmpty ||
                    roomCtrl.text.trim().isEmpty ||
                    start == null ||
                    end == null) {
                  return;
                }
                final startM = start!.hour * 60 + start!.minute;
                final endM = end!.hour * 60 + end!.minute;
                if (endM <= startM) return;
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
              child: const Text('Save session'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final Color? badgeColor;
  final bool pulse;

  const _SectionHeader({
    required this.title,
    required this.count,
    this.badgeColor,
    this.pulse = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
            color: context.appColors.mutedText,
          ),
        ),
        const SizedBox(width: 8),
        TelemetryBadge(
          label: '$count',
          color: badgeColor ?? context.appColors.blue,
          pulse: pulse,
        ),
      ],
    );
  }
}

class _SessionCard extends StatelessWidget {
  final SessionEntry session;
  final bool isLive;
  final bool compact;
  final VoidCallback onDelete;

  const _SessionCard({
    required this.session,
    required this.isLive,
    required this.compact,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isLive
        ? context.appColors.accent.withValues(alpha: 0.5)
        : Theme.of(context).dividerColor;

    return AppPanel(
      radius: 16,
      showReticles: isLive,
      borderColor: borderColor,
      color: isLive
          ? context.appColors.accentSoft.withValues(alpha: 0.08)
          : Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon block
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isLive
                      ? context.appColors.accentSoft
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isLive
                        ? context.appColors.accent.withValues(alpha: 0.4)
                        : Theme.of(context).dividerColor,
                  ),
                ),
                child: Icon(
                  isLive ? Icons.sensors_rounded : Icons.class_outlined,
                  color: isLive
                      ? context.appColors.accentDark
                      : context.appColors.mutedText,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),

              // Title and details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            session.title,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2,
                                ),
                          ),
                        ),
                        if (isLive)
                          TelemetryBadge(
                            label: 'LIVE',
                            pulse: true,
                            color: context.appColors.accent,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      session.room,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.appColors.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Metadata row & Action buttons
          Row(
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  AppPillTag(
                    label: session.timeLabel,
                    icon: Icons.schedule_rounded,
                  ),
                  AppPillTag(
                    label: '${session.expected} EXPECTED',
                    icon: Icons.people_outline_rounded,
                  ),
                ],
              ),
              const Spacer(),
              if (isLive) ...[
                FilledButton.icon(
                  onPressed: () => context.push('/kiosk'),
                  icon: const Icon(Icons.camera_alt_rounded, size: 16),
                  label: Text(compact ? 'Kiosk' : 'Launch Kiosk'),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: context.appColors.accent,
                    foregroundColor: const Color(0xFF042114),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              IconButton(
                visualDensity: VisualDensity.compact,
                iconSize: 18,
                tooltip: 'Delete session',
                style: IconButton.styleFrom(
                  foregroundColor: context.appColors.mutedText,
                ),
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
