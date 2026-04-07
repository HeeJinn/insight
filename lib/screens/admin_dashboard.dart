import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_ce/hive.dart';
import '../app_theme.dart';
import '../models/attendance.dart';
import '../models/student.dart';
import '../providers/hive_provider.dart';
import '../widgets/app_chrome.dart';
import '../widgets/attendance_logs.dart';
import '../widgets/responsive_utils.dart';
import '../widgets/student_list.dart';
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
    _tabController = TabController(length: 3, vsync: this);
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

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: const Text('Admin'),
      ),
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
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _TopActionsBar(
                            studentCount: studentsBox.length,
                            attendanceCount: attendanceBox.length,
                          ),
                          const SizedBox(height: 12),
                          _DashboardTabBar(
                            compact: compact,
                            tabController: _tabController,
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: _DashboardTabView(
                              tabController: _tabController,
                              studentsBox: studentsBox,
                              attendanceBox: attendanceBox,
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
}

class _TopActionsBar extends StatelessWidget {
  final int studentCount;
  final int attendanceCount;

  const _TopActionsBar({
    required this.studentCount,
    required this.attendanceCount,
  });

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Admin',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              IconButton.filledTonal(
                onPressed: () => context.push('/kiosk'),
                icon: const Icon(Icons.camera_alt_outlined),
                tooltip: 'Kiosk',
              ),
              const SizedBox(width: 6),
              IconButton.filledTonal(
                onPressed: () => context.push('/insights'),
                icon: const Icon(Icons.query_stats_outlined),
                tooltip: 'Insights',
              ),
              const SizedBox(width: 6),
              IconButton.filledTonal(
                onPressed: () => context.push('/students'),
                icon: const Icon(Icons.groups_outlined),
                tooltip: 'Students',
              ),
              const SizedBox(width: 6),
              IconButton.filledTonal(
                onPressed: () => context.push('/settings'),
                icon: const Icon(Icons.tune_outlined),
                tooltip: 'Settings',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatChip(
                icon: Icons.groups_2_outlined,
                label: '$studentCount students',
              ),
              _StatChip(
                icon: Icons.event_note_outlined,
                label: '$attendanceCount logs',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16, color: AppTheme.muted),
      label: Text(label),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
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
    return TabBar(
      controller: tabController,
      isScrollable: compact,
      tabAlignment: compact ? TabAlignment.start : TabAlignment.fill,
      dividerColor: scheme.outlineVariant,
      indicatorColor: scheme.primary,
      labelColor: scheme.onSurface,
      unselectedLabelColor: scheme.onSurfaceVariant,
      labelStyle: const TextStyle(fontWeight: FontWeight.w700),
      tabs: [
        Tab(
          icon: const Icon(Icons.person_add_alt_1_outlined),
          child: Text(compact ? 'Register' : 'Register'),
        ),
        const Tab(icon: Icon(Icons.groups_2_outlined), text: 'Students'),
        const Tab(icon: Icon(Icons.event_note_outlined), text: 'Logs'),
      ],
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
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1040),
              child: const StudentRegistration(),
            ),
          ),
        ),
        StreamBuilder(
          stream: studentsBox.watch(),
          builder: (context, _) => StudentList(studentsBox: studentsBox),
        ),
        StreamBuilder(
          stream: attendanceBox.watch(),
          builder: (context, _) => AttendanceLogs(
            attendanceBox: attendanceBox,
            studentsBox: studentsBox,
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
      padding: const EdgeInsets.only(bottom: 8),
      child: child,
    );
  }
}
