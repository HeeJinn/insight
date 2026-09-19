import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_ce/hive.dart';
import '../app_theme.dart';
import '../core/widgets/core_widgets.dart';
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
        child: AppAsyncView.combine2(
          a: studentsAsync,
          b: attendanceAsync,
          data: (context, studentsBox, attendanceBox) {
            // Box providers only resolve once; without watching the boxes
            // directly, changes made elsewhere (e.g. a kiosk scan or a new
            // student registration) wouldn't show up here until something
            // else triggered a rebuild.
            return StreamBuilder(
              stream: studentsBox.watch(),
              builder: (context, _) => StreamBuilder(
                stream: attendanceBox.watch(),
                builder: (context, _) {
                  final width = MediaQuery.sizeOf(context).width;
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
                                onShowInfo: _showAdminInfo,
                                onOpenKiosk: () => context.push('/kiosk'),
                                onOpenSettings: () => context.push('/settings'),
                              ),
                              const SizedBox(height: 12),
                              _TopActionsBar(
                                studentCount: studentsBox.length,
                                attendanceCount: attendanceBox.length,
                                flavors: flavors,
                              ),
                              const SizedBox(height: 8),
                              _DashboardTabBar(
                                tabController: _tabController,
                                logCount: attendanceBox.length,
                              ),
                              const SizedBox(height: 8),
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
            );
          },
        ),
      ),
    );
  }

  void _showAdminInfo() {
    AppDialog.show<void>(
      context,
      title: 'Admin Terminal',
      content: Text(
        'Manages facial embedding baselines (5-photo vectors), local encrypted attendance logs, hardware thresholds, and kiosk deployment triggers.',
        style: AppleTypography.subhead.copyWith(
          color: context.appColors.secondaryText,
        ),
      ),
      actions: (dialogContext) => [
        Expanded(
          child: AppleTactileButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Done'),
          ),
        ),
      ],
    );
  }
}

class _AdminTitleHeader extends StatelessWidget {
  final VoidCallback onShowInfo;
  final VoidCallback onOpenKiosk;
  final VoidCallback onOpenSettings;

  const _AdminTitleHeader({
    required this.onShowInfo,
    required this.onOpenKiosk,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateLabel =
        '${_weekday(now.weekday)}, ${_month(now.month)} ${now.day}'
            .toUpperCase();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateLabel,
                  style: AppleTypography.caption1.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                    color: context.appColors.secondaryText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Admin',
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
              onShowInfo();
            },
            icon: Icon(
              Icons.info_outline_rounded,
              size: 22,
              color: context.appColors.secondaryText,
            ),
            tooltip: 'Info',
          ),
          IconButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              onOpenKiosk();
            },
            icon: Icon(
              Icons.camera_alt_outlined,
              size: 22,
              color: context.appColors.blue,
            ),
            tooltip: 'Kiosk Scanner',
          ),
          IconButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              onOpenSettings();
            },
            icon: Icon(
              Icons.tune_rounded,
              size: 22,
              color: context.appColors.primaryText,
            ),
            tooltip: 'Settings',
          ),
        ],
      ),
    );
  }

  String _weekday(int d) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return days[(d - 1).clamp(0, 6)];
  }

  String _month(int m) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[(m - 1).clamp(0, 11)];
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

    return AppleInsetGroupedSection(
      header: 'Terminal Overview',
      margin: const EdgeInsets.only(bottom: 12),
      children: [
        AppleListRow(
          leading: AppIconBadge(
            icon: Icons.people_alt_rounded,
            tint: context.appColors.blue,
          ),
          title: 'Registered Students',
          subtitle: 'Active biometric facial profiles',
          trailing: Text(
            '$studentCount',
            style: AppleTypography.tabularNumber(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: context.appColors.primaryText,
            ),
          ),
          showChevron: true,
          onTap: () => context.go('/students'),
        ),
        AppleListRow(
          leading: AppIconBadge(
            icon: Icons.event_note_rounded,
            tint: context.appColors.success,
          ),
          title: 'Logged Check-ins',
          subtitle: 'Verified attendance events',
          trailing: Text(
            '$attendanceCount',
            style: AppleTypography.tabularNumber(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: context.appColors.primaryText,
            ),
          ),
          showChevron: true,
          onTap: () => context.push('/insights/logs'),
        ),
        AppleListRow(
          leading: AppIconBadge(
            icon: Icons.palette_outlined,
            tint: context.appColors.warning,
          ),
          title: 'Flavor Studio Profiles',
          subtitle: 'UI theme dynamic presets',
          trailing: Text(
            '$liveFlavors active',
            style: AppleTypography.footnote.copyWith(
              color: context.appColors.secondaryText,
            ),
          ),
          showChevron: true,
          onTap: () => context.push('/flavor-studio'),
        ),
      ],
    );
  }
}

class _DashboardTabBar extends StatefulWidget {
  final TabController tabController;
  final int logCount;

  const _DashboardTabBar({required this.tabController, required this.logCount});

  @override
  State<_DashboardTabBar> createState() => _DashboardTabBarState();
}

class _DashboardTabBarState extends State<_DashboardTabBar> {
  @override
  void initState() {
    super.initState();
    widget.tabController.addListener(_handleTabChange);
  }

  @override
  void dispose() {
    widget.tabController.removeListener(_handleTabChange);
    super.dispose();
  }

  void _handleTabChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: CupertinoSlidingSegmentedControl<int>(
        groupValue: widget.tabController.index,
        backgroundColor: isDark
            ? context.appColors.surface
            : const Color(0xFFE5E5EA),
        thumbColor: isDark ? context.appColors.elevatedSurface : Colors.white,
        children: {
          0: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_add_alt_1_rounded, size: 16),
                SizedBox(width: 8),
                Text('Enrollment'),
              ],
            ),
          ),
          1: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.event_note_rounded, size: 16),
                const SizedBox(width: 8),
                Text('Logs (${widget.logCount})'),
              ],
            ),
          ),
        },
        onValueChanged: (value) {
          if (value != null) {
            HapticFeedback.selectionClick();
            widget.tabController.animateTo(value);
          }
        },
      ),
    );
  }
}

class _DashboardCardFrame extends StatelessWidget {
  final Widget child;

  const _DashboardCardFrame({required this.child});

  @override
  Widget build(BuildContext context) {
    return AppleInsetGroupedSection(
      children: [Padding(padding: const EdgeInsets.all(16), child: child)],
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
