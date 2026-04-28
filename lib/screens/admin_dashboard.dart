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
                            title: 'Admin',
                            subtitle:
                                'Manage registration flow, logs, and kiosk controls',
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
                                  child: SizedBox(height: 10),
                                ),
                                SliverPersistentHeader(
                                  pinned: true,
                                  delegate: _TabBarHeaderDelegate(
                                    child: _DashboardTabBar(
                                      compact: compact,
                                      tabController: _tabController,
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
        title: const Text('Admin'),
        content: const Text(
          'Registration, student data, and attendance logs.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _AdminTitleHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onShowInfo;
  final VoidCallback onOpenKiosk;
  final VoidCallback onOpenSettings;

  const _AdminTitleHeader({
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
                    title,
                    style: compact
                        ? Theme.of(context).textTheme.headlineMedium
                        : Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            _TopIconAction(
              icon: Icons.info_outline,
              tooltip: 'About this page',
              onPressed: onShowInfo,
            ),
            const SizedBox(width: 6),
            _TopIconAction(
              icon: Icons.camera_alt_outlined,
              tooltip: 'Kiosk',
              onPressed: onOpenKiosk,
            ),
            const SizedBox(width: 6),
            _TopIconAction(
              icon: Icons.tune_outlined,
              tooltip: 'Settings',
              onPressed: onOpenSettings,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Row(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                dateLabel,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                'Admin workspace',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Overview', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MetricMiniTile(
                  label: 'Students',
                  value: '$studentCount',
                  icon: Icons.groups_2_outlined,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricMiniTile(
                  label: 'Check-ins',
                  value: '$attendanceCount',
                  icon: Icons.event_note_outlined,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricMiniTile(
                  label: 'Live flavors',
                  value: '$liveFlavors',
                  icon: Icons.palette_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _QuickNavButton(
                icon: Icons.query_stats_outlined,
                label: 'Insights',
                onPressed: () => context.go('/insights'),
              ),
              _QuickNavButton(
                icon: Icons.groups_outlined,
                label: 'Students',
                onPressed: () => context.go('/students'),
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

  const _MetricMiniTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.muted),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
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
    return FilledButton.tonalIcon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 38),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
      icon: Icon(icon, size: 18),
      label: Text(label),
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

  const _DashboardTabBar({required this.compact, required this.tabController});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.96),
      padding: const EdgeInsets.only(top: 4),
      child: TabBar(
        controller: tabController,
        isScrollable: compact,
        tabAlignment: compact ? TabAlignment.start : TabAlignment.fill,
        dividerColor: Colors.transparent,
        indicatorColor: scheme.primary,
        indicatorWeight: 2.5,
        labelColor: scheme.onSurface,
        unselectedLabelColor: scheme.onSurfaceVariant,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700),
        tabs: [
          const Tab(
            icon: Icon(Icons.person_add_alt_1_outlined),
            text: 'Register',
          ),
          const Tab(icon: Icon(Icons.event_note_outlined), text: 'Logs'),
        ],
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
      padding: const EdgeInsets.all(12),
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
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: child,
    );
  }
}

class _TabBarHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  const _TabBarHeaderDelegate({required this.child});

  @override
  double get minExtent => 56;

  @override
  double get maxExtent => 56;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _TabBarHeaderDelegate oldDelegate) {
    return child != oldDelegate.child;
  }
}
