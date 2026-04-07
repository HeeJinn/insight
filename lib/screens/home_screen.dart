import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_ce/hive.dart';
import '../app_theme.dart';
import '../models/attendance.dart';
import '../models/student.dart';
import '../providers/app_state_provider.dart';
import '../providers/hive_provider.dart';
import '../widgets/app_chrome.dart';
import '../widgets/responsive_utils.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrap = ref.watch(appStateBootstrapProvider);
    final onboardingDone = ref.watch(onboardingDoneProvider);
    final studentsAsync = ref.watch(studentsBoxProvider);
    final attendanceAsync = ref.watch(attendanceBoxProvider);

    if (bootstrap.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (bootstrap.hasError) {
      return Scaffold(body: Center(child: Text('Init error: ${bootstrap.error}')));
    }
    if (!onboardingDone) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/onboarding');
      });
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }
        final shouldExit = await showDialog<bool>(
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
        body: AppBackground(
          child: LayoutBuilder(
            builder: (context, constraints) {
            final width = constraints.maxWidth;
            final compact = AppBreakpoints.isCompact(width);
            final contentWidth = AppBreakpoints.contentWidth(width);
            final padding = AppBreakpoints.pagePadding(width);

            return SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: contentWidth),
                  child: ListView(
                    padding: padding,
                    children: [
                      _TopBar(compact: compact),
                      const SizedBox(height: 14),
                      _SummaryCard(
                        compact: compact,
                        studentsBox: studentsAsync.maybeWhen(
                          data: (box) => box,
                          orElse: () => null,
                        ),
                        attendanceBox: attendanceAsync.maybeWhen(
                          data: (box) => box,
                          orElse: () => null,
                        ),
                      ),
                      if (kIsWeb) ...[
                        const SizedBox(height: 14),
                        const AppPanel(
                          color: AppTheme.warningSoft,
                          radius: 18,
                          padding: EdgeInsets.all(14),
                          child: Text(
                            'Web is view-only for this prototype. Use Android, iOS, or desktop for registration and live scanning.',
                            style: TextStyle(color: AppTheme.ink, height: 1.5),
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
                            icon: Icons.dashboard_outlined,
                            onTap: kIsWeb ? null : () => context.push('/admin'),
                          ),
                          _QuickActionData(
                            label: 'Kiosk',
                            icon: Icons.camera_alt_outlined,
                            onTap: kIsWeb ? null : () => context.push('/kiosk'),
                          ),
                          _QuickActionData(
                            label: 'Insights',
                            icon: Icons.query_stats_outlined,
                            onTap: () => context.push('/insights'),
                          ),
                          _QuickActionData(
                            label: 'Students',
                            icon: Icons.groups_outlined,
                            onTap: () => context.push('/students'),
                          ),
                          _QuickActionData(
                            label: 'Sessions',
                            icon: Icons.schedule_outlined,
                            onTap: () => context.push('/sessions'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const _AnimatedHighlightCard(),
                      const SizedBox(height: 18),
                      AppPanel(
                        radius: 18,
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppTheme.accentSoft,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.lock_outline,
                                color: AppTheme.accentDark,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Everything stays offline on-device. No internet required.',
                                style: TextStyle(color: AppTheme.muted),
                              ),
                            ),
                          ],
                        ),
                      ),
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

class _TopBar extends StatelessWidget {
  final bool compact;

  const _TopBar({required this.compact});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Good ${_timeOfDayGreeting()}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Attendance',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontSize: compact ? 26 : 30,
                    ),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          onPressed: () => context.push('/settings'),
          icon: const Icon(Icons.tune_outlined),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final bool compact;
  final Box<Student>? studentsBox;
  final Box<Attendance>? attendanceBox;

  const _SummaryCard({
    required this.compact,
    required this.studentsBox,
    required this.attendanceBox,
  });

  @override
  Widget build(BuildContext context) {
    final students = studentsBox;
    final attendance = attendanceBox;
    if (students == null || attendance == null) {
      return const AppPanel(
        radius: 18,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return StreamBuilder(
      stream: students.watch(),
      builder: (context, _) => StreamBuilder(
        stream: attendance.watch(),
        builder: (context, _) {
          final studentsCount = students.length;
          final logsCount = attendance.length;
          return AppPanel(
            radius: 18,
            padding: EdgeInsets.all(compact ? 16 : 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.accentSoft,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.verified_outlined, color: AppTheme.accentDark),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Ready to scan',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    AppPillTag(
                      label: '$studentsCount students',
                      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                      foregroundColor: AppTheme.muted,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Open kiosk mode to record attendance offline.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: kIsWeb ? null : () => context.push('/kiosk'),
                        child: const Text('Start kiosk'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => context.push('/admin'),
                        child: Text('Admin • $logsCount logs'),
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

class _ActionCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  const _ActionCard({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AppPanel(
        radius: 18,
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Theme.of(context).colorScheme.onSurface),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionsGrid extends StatelessWidget {
  final bool compact;
  final List<_QuickActionData> actions;

  const _QuickActionsGrid({
    required this.compact,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 920 ? 4 : width >= 620 ? 3 : 2;
        final childAspectRatio = compact ? 1.55 : 1.7;

        return GridView.builder(
          itemCount: actions.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: childAspectRatio,
          ),
          itemBuilder: (context, index) {
            final action = actions[index];
            return _ActionCard(
              label: action.label,
              icon: action.icon,
              onTap: action.onTap,
            );
          },
        );
      },
    );
  }
}

class _QuickActionData {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  const _QuickActionData({
    required this.label,
    required this.icon,
    required this.onTap,
  });
}

class _AnimatedHighlightCard extends StatelessWidget {
  const _AnimatedHighlightCard();

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      radius: 18,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppTheme.accentSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: AppTheme.accentDark,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Live scanning, insights, and records are ready for your next session.',
              style: TextStyle(color: AppTheme.muted),
            ),
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
