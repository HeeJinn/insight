import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_ce/hive.dart';
import '../app_theme.dart';
import '../models/attendance.dart';
import '../models/session_entry.dart';
import '../models/student.dart';
import '../providers/hive_provider.dart';
import '../providers/sessions_provider.dart';
import '../widgets/app_chrome.dart';
import '../widgets/responsive_utils.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentsAsync = ref.watch(studentsBoxProvider);
    final attendanceAsync = ref.watch(attendanceBoxProvider);
    final sessions = ref.watch(sessionsProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }
        final shouldExit =
            await showDialog<bool>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('Exit app?'),
                content: const Text('Do you want to close Insight now?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    child: const Text('Exit'),
                  ),
                ],
              ),
            ) ??
            false;

        if (shouldExit) {
          await SystemNavigator.pop();
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: AppBackground(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final compact = AppBreakpoints.isCompact(width);
              final contentWidth = AppBreakpoints.contentWidth(width);
              final padding = AppBreakpoints.pagePadding(width);
              final bottomSafeGap = AppBreakpoints.navAwareBottomInset(context);

              return SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: contentWidth),
                    child: ListView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: padding.copyWith(bottom: bottomSafeGap),
                      children: [
                        _Header(compact: compact),
                        const SizedBox(height: 16),
                        _KioskHeroCard(
                          studentsBox: studentsAsync.maybeWhen(
                            data: (box) => box,
                            orElse: () => null,
                          ),
                          attendanceBox: attendanceAsync.maybeWhen(
                            data: (box) => box,
                            orElse: () => null,
                          ),
                        ),
                        const SizedBox(height: 18),
                        _OverviewPanel(
                          studentsBox: studentsAsync.maybeWhen(
                            data: (box) => box,
                            orElse: () => null,
                          ),
                          attendanceBox: attendanceAsync.maybeWhen(
                            data: (box) => box,
                            orElse: () => null,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _TodaySessionsStrip(sessions: sessions),
                        if (kIsWeb) ...[
                          const SizedBox(height: 14),
                          const AppPanel(
                            color: AppTheme.warningSoft,
                            radius: 18,
                            padding: EdgeInsets.all(14),
                            child: Text(
                              'Web is view-only for this prototype. Use Android, iOS, or desktop for registration and live scanning.',
                              style: TextStyle(
                                color: AppTheme.ink,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        Text(
                          'Quick actions',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 10),
                        _QuickActionsGrid(
                          compact: compact,
                          actions: [
                            _QuickActionData(
                              label: 'Admin',
                              subtitle: 'Manage system',
                              icon: Icons.security_rounded,
                              color: Theme.of(context).colorScheme.primary,
                              onTap: () => context.go('/admin'),
                            ),
                            _QuickActionData(
                              label: 'Kiosk',
                              subtitle: 'Open kiosk mode',
                              icon: Icons.qr_code_scanner_rounded,
                              color: Theme.of(context).colorScheme.secondary,
                              onTap: kIsWeb
                                  ? null
                                  : () => context.push('/kiosk'),
                            ),
                            _QuickActionData(
                              label: 'Insights',
                              subtitle: 'View reports',
                              icon: Icons.insights_rounded,
                              color: Theme.of(context).colorScheme.tertiary,
                              onTap: () => context.go('/insights'),
                            ),
                            _QuickActionData(
                              label: 'Students',
                              subtitle: 'Manage students',
                              icon: Icons.groups_rounded,
                              color: Theme.of(context).colorScheme.primary,
                              onTap: () => context.go('/students'),
                            ),
                            _QuickActionData(
                              label: 'Sessions',
                              subtitle: 'Past classes',
                              icon: Icons.schedule_rounded,
                              color: Theme.of(context).colorScheme.secondary,
                              onTap: () => context.go('/sessions'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const _SystemStatusCard(),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final bool compact;

  const _Header({required this.compact});

  @override
  Widget build(BuildContext context) {
    final titleSize = compact ? 38.0 : 44.0;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Good ${_timeOfDayGreeting()}',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Attendance',
                style: Theme.of(
                  context,
                ).textTheme.displayMedium?.copyWith(fontSize: titleSize),
              ),
              const SizedBox(height: 2),
              Text(
                "Here's what's happening today",
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => context.push('/settings'),
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: const Icon(Icons.settings_outlined),
          ),
        ),
      ],
    );
  }
}

class _KioskHeroCard extends StatelessWidget {
  final Box<Student>? studentsBox;
  final Box<Attendance>? attendanceBox;

  const _KioskHeroCard({
    required this.studentsBox,
    required this.attendanceBox,
  });

  @override
  Widget build(BuildContext context) {
    if (studentsBox == null || attendanceBox == null) {
      return const AppPanel(
        radius: 22,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return StreamBuilder(
      stream: studentsBox!.watch(),
      builder: (context, _) => StreamBuilder(
        stream: attendanceBox!.watch(),
        builder: (context, _) {
          final studentsCount = studentsBox!.length;
          final now = DateTime.now();
          final dayStart = DateTime(now.year, now.month, now.day);
          final detectedToday = attendanceBox!.values
              .where((item) => item.timestamp.isAfter(dayStart))
              .map((item) => item.studentId)
              .toSet()
              .length;

          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'KIOSK STATUS',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    letterSpacing: 1.1,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Ready to scan',
                  style: Theme.of(
                    context,
                  ).textTheme.headlineMedium?.copyWith(fontSize: 34),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.circle, size: 10, color: AppTheme.accent),
                    const SizedBox(width: 8),
                    Text(
                      '$detectedToday student${detectedToday == 1 ? '' : 's'} detected today',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const Spacer(),
                    AppPillTag(
                      label: '$studentsCount rostered',
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      foregroundColor: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: kIsWeb ? null : () => context.push('/kiosk'),
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    label: const Text('Start kiosk'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _ActionCard({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionsGrid extends StatelessWidget {
  final bool compact;
  final List<_QuickActionData> actions;

  const _QuickActionsGrid({required this.compact, required this.actions});

  @override
  Widget build(BuildContext context) {
    final columns = compact ? 1 : 2;
    return GridView.builder(
      itemCount: actions.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: compact ? 2.8 : 2.3,
      ),
      itemBuilder: (context, index) {
        final action = actions[index];
        return _ActionCard(
          label: action.label,
          subtitle: action.subtitle,
          icon: action.icon,
          color: action.color,
          onTap: action.onTap,
        );
      },
    );
  }
}

class _QuickActionData {
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _QuickActionData({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

class _OverviewPanel extends StatelessWidget {
  final Box<Student>? studentsBox;
  final Box<Attendance>? attendanceBox;

  const _OverviewPanel({
    required this.studentsBox,
    required this.attendanceBox,
  });

  @override
  Widget build(BuildContext context) {
    if (studentsBox == null || attendanceBox == null) {
      return const AppPanel(
        radius: 22,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return StreamBuilder(
      stream: studentsBox!.watch(),
      builder: (context, _) => StreamBuilder(
        stream: attendanceBox!.watch(),
        builder: (context, _) {
          final now = DateTime.now();
          final dayStart = DateTime(now.year, now.month, now.day);
          final todaysLogs = attendanceBox!.values
              .where((item) => item.timestamp.isAfter(dayStart))
              .toList();
          final present = todaysLogs
              .map((item) => item.studentId)
              .toSet()
              .length;
          final total = studentsBox!.length;
          final absent = (total - present).clamp(0, total);
          final late = todaysLogs
              .where((item) => item.timestamp.hour >= 9)
              .length;

          return AppPanel(
            radius: 22,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Today's overview",
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _OverviewStatTile(
                        label: 'Present',
                        value: '$present',
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _OverviewStatTile(
                        label: 'Absent',
                        value: '$absent',
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _OverviewStatTile(
                        label: 'Late',
                        value: '$late',
                        color: Theme.of(context).colorScheme.tertiary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _OverviewStatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _OverviewStatTile({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 6),
          Text(value, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Container(
            height: 5,
            width: 44,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ],
      ),
    );
  }
}

class _SystemStatusCard extends StatelessWidget {
  const _SystemStatusCard();

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      radius: 22,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.wifi_tethering_rounded,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'System status',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 2),
                Text(
                  'All systems operational',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            'Last sync\n2 mins ago',
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

String _timeOfDayGreeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'morning';
  if (hour < 18) return 'afternoon';
  return 'evening';
}

class _TodaySessionsStrip extends StatelessWidget {
  final List<SessionEntry> sessions;

  const _TodaySessionsStrip({required this.sessions});

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      radius: 20,
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(
            Icons.timeline_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              sessions.isEmpty
                  ? 'No sessions planned yet.'
                  : '${sessions.length} session${sessions.length == 1 ? '' : 's'} scheduled today',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          TextButton(
            onPressed: () => GoRouter.of(context).go('/sessions'),
            child: const Text('Open'),
          ),
        ],
      ),
    );
  }
}
