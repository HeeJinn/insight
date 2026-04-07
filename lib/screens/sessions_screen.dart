import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/session_entry.dart';
import '../app_theme.dart';
import '../providers/sessions_provider.dart';
import '../widgets/app_chrome.dart';
import '../widgets/responsive_utils.dart';

class SessionsScreen extends ConsumerWidget {
  const SessionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(sessionsProvider);
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: const Text('Sessions'),
      ),
      body: AppBackground(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final contentWidth = AppBreakpoints.contentWidth(width);
            final padding = AppBreakpoints.pagePadding(width);
            final compact = AppBreakpoints.isCompact(width);

            return SafeArea(
              child: SingleChildScrollView(
                padding: padding,
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: contentWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AppPanel(
                          child: AppSectionHeading(
                            eyebrow: 'Class sessions',
                            title: 'Today\'s Schedule',
                            subtitle:
                                'Prototype timetable for quick launch into kiosk and attendance scanning.',
                            compact: false,
                          ),
                        ),
                        const SizedBox(height: 18),
                        if (sessions.isEmpty)
                          const AppPanel(
                            child: Text('No sessions yet. Tap + to add one.'),
                          )
                        else
                          ...sessions.map(
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
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSessionDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add session'),
      ),
    );
  }

  Future<void> _showAddSessionDialog(BuildContext context, WidgetRef ref) async {
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
                  decoration: const InputDecoration(labelText: 'Course / Session title'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: roomCtrl,
                  decoration: const InputDecoration(labelText: 'Room'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: expectedCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Expected students'),
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
                        child: Text(start == null ? 'Start' : start!.format(context)),
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
                ref.read(sessionsProvider.notifier).addSession(
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: AppTheme.accentGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.schedule, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(session.title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 6),
                Text(session.room, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    AppPillTag(
                      label: session.timeLabel,
                      icon: Icons.access_time_rounded,
                      backgroundColor: AppTheme.orangeSoft,
                      foregroundColor: AppTheme.orange,
                    ),
                    AppPillTag(
                      label: '${session.expected} expected',
                      icon: Icons.groups_2_outlined,
                      backgroundColor: AppTheme.blueSoft,
                      foregroundColor: AppTheme.blue,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            children: [
              if (!compact)
                OutlinedButton.icon(
                  onPressed: () => context.push('/kiosk'),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Start Kiosk'),
                ),
              const SizedBox(height: 8),
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
