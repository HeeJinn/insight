import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_ce/hive.dart';
import '../app_theme.dart';
import '../models/attendance.dart';
import '../models/flavor_profile.dart';
import '../models/student.dart';
import '../providers/flavor_profiles_provider.dart';
import '../providers/hive_provider.dart';
import '../widgets/app_chrome.dart';
import '../widgets/attendance_logs.dart';
import '../widgets/biometric_indicators.dart';
import '../widgets/responsive_utils.dart';
import '../widgets/student_registration.dart';

class AdminDashboard extends ConsumerStatefulWidget {
  const AdminDashboard({super.key});

  @override
  ConsumerState<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<AdminDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(studentsBoxProvider);
    final attendanceAsync = ref.watch(attendanceBoxProvider);
    final flavors = ref.watch(flavorProfilesProvider);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: AppBackground(
        child: studentsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(child: Text('Error: $error')),
          data: (studentsBox) => attendanceAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text('Error: $error')),
            data: (attendanceBox) {
              final width = MediaQuery.sizeOf(context).width;
              final compact = AppBreakpoints.isCompact(width);
              final contentWidth = AppBreakpoints.contentWidth(width);
              final padding = AppBreakpoints.pagePadding(width);

              return SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: contentWidth),
                    child: Padding(
                      padding: padding,
                      child: Column(
                        children: [
                          _AdminTitleHeader(
                            eyebrow: 'SYSTEM CONTROL & ENROLLMENT',
                            title: 'Admin Terminal',
                            subtitle:
                                'Biometric registration, telemetry logs, and kiosk management',
                            onShowInfo: _showAdminInfo,
                            onOpenKiosk: () => context.push('/kiosk'),
                            onOpenSettings: () => context.push('/settings'),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: NestedScrollView(
                              headerSliverBuilder: (context, _) => [
                                SliverToBoxAdapter(
                                  child: _TopActionsBar(
                                    studentCount: studentsBox.length,
                                    attendanceCount: attendanceBox.length,
                                    flavors: flavors,
                                  ),
                                ),
                                const SliverToBoxAdapter(
                                  child: SizedBox(height: 12),
                                ),
                                SliverPersistentHeader(
                                  pinned: true,
                                  delegate: _TabBarHeaderDelegate(
                                    child: _DashboardTabBar(
                                      compact: compact,
                                      tabController: _tabController,
                                      logCount: attendanceBox.length,
                                    ),
                                  ),
                                ),
                              ],
                              body: _DashboardTabView(
                                tabController: _tabController,
                                studentsBox: studentsBox,
                                attendanceBox: attendanceBox,
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
      ),
    );
  }

  void _showAdminInfo() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Theme.of(context).dividerColor),
        ),
        title: const Text('Insight Admin Terminal'),
        content: const Text(
          'Manages facial embedding baselines (5-photo vectors), local encrypted attendance logs, hardware thresholds, and kiosk deployment triggers.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );
  }
}

class _AdminTitleHeader extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final VoidCallback onShowInfo;
  final VoidCallback onOpenKiosk;
  final VoidCallback onOpenSettings;

  const _AdminTitleHeader({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.onShowInfo,
    required this.onOpenKiosk,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final compact = AppBreakpoints.isCompact(MediaQuery.sizeOf(context).width);
    final now = DateTime.now();
    final dateLabel =
        '${_weekdayShort(now.weekday)}, ${_monthShort(now.month)} ${now.day}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    eyebrow.toUpperCase(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700,
                      color: context.appColors.accentDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: compact
                        ? Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          )
                        : Theme.of(context).textTheme.headlineLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.appColors.mutedText,
                    ),
                  ),
                ],
              ),
            ),
            _TopIconAction(
              icon: Icons.info_outline_rounded,
              tooltip: 'Terminal Info',
              onPressed: onShowInfo,
            ),
            const SizedBox(width: 6),
            _TopIconAction(
              icon: Icons.camera_alt_outlined,
              tooltip: 'Engage Kiosk',
              onPressed: onOpenKiosk,
            ),
            const SizedBox(width: 6),
            _TopIconAction(
              icon: Icons.tune_rounded,
              tooltip: 'Hardware Settings',
              onPressed: onOpenSettings,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Row(
            children: [
              Icon(
                Icons.calendar_today_rounded,
                size: 14,
                color: context.appColors.mutedText,
              ),
              const SizedBox(width: 8),
              Text(
                dateLabel,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.appColors.mutedText,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const Spacer(),
              TelemetryBadge(
                label: 'ENROLLMENT WORKSPACE',
                color: context.appColors.blue,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TopActionsBar extends StatelessWidget {
  final int studentCount;
  final int attendanceCount;
  final List<FlavorProfile> flavors;

  const _TopActionsBar({
    required this.studentCount,
    required this.attendanceCount,
    required this.flavors,
  });

  @override
  Widget build(BuildContext context) {
    final liveFlavors = flavors.where((profile) => profile.enabled).length;

    return AppPanel(
      radius: 16,
      padding: const EdgeInsets.all(14),
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'SYSTEM TELEMETRY SUMMARY',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  letterSpacing: 1.0,
                  fontWeight: FontWeight.w700,
                  color: context.appColors.mutedText,
                ),
              ),
              const Spacer(),
              TelemetryBadge(
                label: 'HIVE LOCAL DB',
                color: context.appColors.accent,
                pulse: false,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MetricMiniTile(
                  label: 'ENROLLED STUDENTS',
                  value: '$studentCount',
                  icon: Icons.groups_2_rounded,
                  accentColor: context.appColors.accent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricMiniTile(
                  label: 'LOGGED EVENTS',
                  value: '$attendanceCount',
                  icon: Icons.event_note_rounded,
                  accentColor: context.appColors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricMiniTile(
                  label: 'ACTIVE FLAVORS',
                  value: '$liveFlavors',
                  icon: Icons.palette_outlined,
                  accentColor: context.appColors.amber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _QuickNavButton(
                icon: Icons.query_stats_rounded,
                label: 'View Insights',
                onPressed: () => context.go('/insights'),
              ),
              _QuickNavButton(
                icon: Icons.groups_rounded,
                label: 'Manage Students',
                onPressed: () => context.go('/students'),
              ),
              _QuickNavButton(
                icon: Icons.auto_awesome_mosaic_outlined,
                label: 'Flavor Studio',
                onPressed: () => context.push('/flavor-studio'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricMiniTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accentColor;

  const _MetricMiniTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: accentColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: context.appColors.mutedText,
                    fontSize: 9.5,
                    letterSpacing: 0.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    fontFeatures: const [FontFeature.tabularFigures()],
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

class _QuickNavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _QuickNavButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide(color: Theme.of(context).dividerColor),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12.5)),
    );
  }
}

class _TopIconAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _TopIconAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      onPressed: onPressed,
      tooltip: tooltip,
      style: IconButton.styleFrom(
        minimumSize: const Size(36, 36),
        padding: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
      icon: Icon(icon, size: 18),
    );
  }
}

class _DashboardTabBar extends StatelessWidget {
  final bool compact;
  final TabController tabController;
  final int logCount;

  const _DashboardTabBar({
    required this.compact,
    required this.tabController,
    required this.logCount,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.96),
      ),
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        padding: const EdgeInsets.all(3),
        child: TabBar(
          controller: tabController,
          dividerColor: Colors.transparent,
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
          labelColor: scheme.onSurface,
          unselectedLabelColor: context.appColors.mutedText,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            letterSpacing: 0.2,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
          tabs: [
            const Tab(
              icon: Icon(Icons.person_add_alt_1_rounded, size: 16),
              text: 'Biometric Enrollment',
              iconMargin: EdgeInsets.only(bottom: 2),
            ),
            Tab(
              icon: const Icon(Icons.event_note_rounded, size: 16),
              text: 'Audit Logs ($logCount)',
              iconMargin: const EdgeInsets.only(bottom: 2),
            ),
          ],
        ),
      ),
    );
  }
}

String _weekdayShort(int weekday) {
  const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return names[(weekday - 1).clamp(0, 6)];
}

String _monthShort(int month) {
  const names = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return names[(month - 1).clamp(0, 11)];
}

class _DashboardCardFrame extends StatelessWidget {
  final Widget child;

  const _DashboardCardFrame({required this.child});

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      radius: 16,
      showReticles: true,
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.30),
      child: child,
    );
  }
}

class _DashboardTabView extends StatelessWidget {
  final TabController tabController;
  final Box<Student> studentsBox;
  final Box<Attendance> attendanceBox;

  const _DashboardTabView({
    required this.tabController,
    required this.studentsBox,
    required this.attendanceBox,
  });

  @override
  Widget build(BuildContext context) {
    return TabBarView(
      controller: tabController,
      children: [
        _DashboardScrollFrame(
          child: _DashboardCardFrame(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1040),
                child: const StudentRegistration(),
              ),
            ),
          ),
        ),
        _DashboardScrollFrame(
          child: _DashboardCardFrame(
            child: StreamBuilder(
              stream: attendanceBox.watch(),
              builder: (context, _) => AttendanceLogs(
                attendanceBox: attendanceBox,
                studentsBox: studentsBox,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DashboardScrollFrame extends StatelessWidget {
  final Widget child;

  const _DashboardScrollFrame({required this.child});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(top: 6, bottom: 80),
      child: child,
    );
  }
}

class _TabBarHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  const _TabBarHeaderDelegate({required this.child});

  @override
  double get minExtent => 54;

  @override
  double get maxExtent => 54;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
      ),
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _TabBarHeaderDelegate oldDelegate) {
    return child != oldDelegate.child;
  }
}
