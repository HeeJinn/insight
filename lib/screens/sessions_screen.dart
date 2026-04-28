import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
            final compact = AppBreakpoints.isCompact(constraints.maxWidth);
            return AppPageScaffold(
              title: 'Sessions',
              subtitle: 'Past and upcoming class attendance windows',
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Today timeline',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: () => _showAddSessionDialog(context, ref),
                        icon: const Icon(Icons.add),
                        label: const Text('Add session'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  AppPanel(
                    radius: 20,
                    padding: const EdgeInsets.all(16),
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Today\'s schedule',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Launch kiosk quickly from each scheduled session.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (sessions.isEmpty)
                    const AppEmptyState(
                      icon: Icons.schedule_outlined,
                      title: 'No sessions yet',
                      subtitle:
                          'Use Add session to create your first class window.',
                    )
                  else ...[
                    if (live.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Live now',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      ...live.map(
                        (session) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _SessionCard(
                            session: session,
                            compact: compact,
                            onDelete: () => ref
                                .read(sessionsProvider.notifier)
                                .removeSession(session.id),
                          ),
                        ),
                      ),
                    ],
                    if (upcoming.isNotEmpty) ...[
                      Text(
                        'Upcoming sessions',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      ...upcoming.map(
                        (session) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _SessionCard(
                            session: session,
                            compact: compact,
                            onDelete: () => ref
                                .read(sessionsProvider.notifier)
                                .removeSession(session.id),
                          ),
                        ),
                      ),
                    ],
                    if (archived.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Archived / past',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      ...archived.map(
                        (session) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _SessionCard(
                            session: session,
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
    final expectedCtrl = TextEditingController(text: '0');
    TimeOfDay? start;
    TimeOfDay? end;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('New session'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  decoration: const InputDecoration(
                    labelText: 'Course / Session title',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: roomCtrl,
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  decoration: const InputDecoration(labelText: 'Room'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: expectedCtrl,
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Expected students',
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final t = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.now(),
                          );
                          if (t != null) setState(() => start = t);
                        },
                        child: Text(
                          start == null ? 'Start' : start!.format(context),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final t = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.now(),
                          );
                          if (t != null) setState(() => end = t);
                        },
                        child: Text(end == null ? 'End' : end!.format(context)),
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
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final SessionEntry session;
  final bool compact;
  final VoidCallback onDelete;

  const _SessionCard({
    required this.session,
    required this.compact,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      radius: 18,
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.schedule,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  session.room,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    AppPillTag(
                      label: session.timeLabel,
                      icon: Icons.access_time_rounded,
                    ),
                    AppPillTag(
                      label: '${session.expected} expected',
                      icon: Icons.groups_2_outlined,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            children: [
              if (!compact) ...[
                OutlinedButton.icon(
                  onPressed: () => context.push('/kiosk'),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Start Kiosk'),
                ),
                const SizedBox(height: 8),
              ],
              IconButton.filledTonal(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
