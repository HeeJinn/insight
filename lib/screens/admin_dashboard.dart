import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 16 : padding.horizontal / 2,
                        vertical: 8,
                      ),
                      child: Column(
                        children: [
                          // 1. Clean Top Header
                          _AdminM3Header(
                            onShowInfo: _showAdminInfo,
                            onOpenKiosk: () => context.push('/kiosk'),
                            onOpenSettings: () => context.push('/settings'),
                          ),
                          const SizedBox(height: 12),

                          // 2. Overview Stats Row
                          _OverviewMetricsRow(
                            studentCount: studentsBox.length,
                            attendanceCount: attendanceBox.length,
                            liveFlavorCount: flavors.where((f) => f.enabled).length,
                          ),
                          const SizedBox(height: 12),

                          // 3. Segmented Navigation Bar
                          _M3SegmentedTabBar(
                            tabController: _tabController,
                            logCount: attendanceBox.length,
                          ),
                          const SizedBox(height: 8),

                          // 4. Tab Content
                          Expanded(
                            child: TabBarView(
                              controller: _tabController,
                              children: [
                                const SingleChildScrollView(
                                  padding: EdgeInsets.only(bottom: 16),
                                  child: StudentRegistration(),
                                ),
                                StreamBuilder(
                                  stream: attendanceBox.watch(),
                                  builder: (context, _) => AttendanceLogs(
                                    attendanceBox: attendanceBox,
                                    studentsBox: studentsBox,
                                  ),
                                ),
                              ],
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
        title: const Text('Admin Console'),
        content: const Text(
          'Manage student face registration, review recognition logs, and launch the kiosk terminal.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

class _AdminM3Header extends StatelessWidget {
  final VoidCallback onShowInfo;
  final VoidCallback onOpenKiosk;
  final VoidCallback onOpenSettings;

  const _AdminM3Header({
    required this.onShowInfo,
    required this.onOpenKiosk,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Admin',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Kiosk #04 · Facial Attendance Terminal',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          icon: const Icon(Icons.info_outline, size: 18),
          tooltip: 'About',
          onPressed: onShowInfo,
        ),
        const SizedBox(width: 6),
        IconButton.filled(
          icon: const Icon(Icons.camera_alt_outlined, size: 18),
          tooltip: 'Launch Kiosk',
          onPressed: onOpenKiosk,
        ),
        const SizedBox(width: 6),
        IconButton.filledTonal(
          icon: const Icon(Icons.tune, size: 18),
          tooltip: 'Settings',
          onPressed: onOpenSettings,
        ),
      ],
    );
  }
}

class _OverviewMetricsRow extends StatelessWidget {
  final int studentCount;
  final int attendanceCount;
  final int liveFlavorCount;

  const _OverviewMetricsRow({
    required this.studentCount,
    required this.attendanceCount,
    required this.liveFlavorCount,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: _M3MetricTile(
            label: 'Students',
            value: '$studentCount',
            icon: Icons.people_alt_outlined,
            color: scheme.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _M3MetricTile(
            label: 'Check-ins',
            value: '$attendanceCount',
            icon: Icons.check_circle_outline,
            color: Colors.greenAccent.shade400,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _M3MetricTile(
            label: 'Profiles',
            value: '$liveFlavorCount',
            icon: Icons.face_retouching_natural,
            color: Colors.amberAccent.shade400,
          ),
        ),
      ],
    );
  }
}

class _M3MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _M3MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _M3SegmentedTabBar extends StatelessWidget {
  final TabController tabController;
  final int logCount;

  const _M3SegmentedTabBar({
    required this.tabController,
    required this.logCount,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.25),
        ),
      ),
      child: AnimatedBuilder(
        animation: tabController,
        builder: (context, _) {
          final isRegistration = tabController.index == 0;
          return Row(
            children: [
              Expanded(
                child: _SegmentButton(
                  icon: Icons.person_add_alt_1,
                  label: 'Registration',
                  isSelected: isRegistration,
                  onTap: () => tabController.animateTo(0),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _SegmentButton(
                  icon: Icons.list_alt_rounded,
                  label: 'Logs ($logCount)',
                  isSelected: !isRegistration,
                  onTap: () => tabController.animateTo(1),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SegmentButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: isSelected ? scheme.surfaceContainerHighest : Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            border: isSelected
                ? Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5))
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? scheme.onSurface : scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}



