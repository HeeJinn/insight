import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_ce/hive.dart';
import '../app_theme.dart';
import '../core/widgets/core_widgets.dart';
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

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: AppBackground(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final contentWidth = AppBreakpoints.contentWidth(width);
            final padding = AppBreakpoints.pagePadding(width);

            return SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: contentWidth),
                  child: ListView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: padding.copyWith(
                      bottom: AppBreakpoints.navAwareBottomInset(context),
                    ),
                    children: [
                      const _AppleHeader(),
                      const SizedBox(height: 20),
                      _TodayAttendanceSection(
                        studentsBox: studentsAsync.maybeWhen(
                          data: (box) => box,
                          orElse: () => null,
                        ),
                        attendanceBox: attendanceAsync.maybeWhen(
                          data: (box) => box,
                          orElse: () => null,
                        ),
                      ),
                      _SessionsSection(sessions: sessions),
                      const _NavigationSection(),
                      const _SystemStatusSection(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AppleHeader extends StatelessWidget {
  const _AppleHeader();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateStr =
        '${_weekday(now.weekday)}, ${_month(now.month)} ${now.day}'.toUpperCase();

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
                  dateStr,
                  style: AppleTypography.caption1.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                    color: context.appColors.secondaryText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Insight',
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
              context.push('/settings');
            },
            icon: Icon(
              Icons.tune_rounded,
              color: context.appColors.primaryText,
              size: 22,
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
      'Sunday'
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
      'December'
    ];
    return months[(m - 1).clamp(0, 11)];
  }
}

class _TodayAttendanceSection extends StatelessWidget {
  final Box<Student>? studentsBox;
  final Box<Attendance>? attendanceBox;

  const _TodayAttendanceSection({
    required this.studentsBox,
    required this.attendanceBox,
  });

  @override
  Widget build(BuildContext context) {
    if (studentsBox == null || attendanceBox == null) {
      return const AppleInsetGroupedSection(
        header: 'Today\'s Attendance',
        children: [
          Padding(
            padding: EdgeInsets.all(24.0),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        ],
      );
    }

    return StreamBuilder(
      stream: studentsBox!.watch(),
      builder: (context, _) => StreamBuilder(
        stream: attendanceBox!.watch(),
        builder: (context, _) {
          final totalStudents = studentsBox!.length;
          final now = DateTime.now();
          final dayStart = DateTime(now.year, now.month, now.day);
          final todaysLogs = attendanceBox!.values
              .where((item) => item.timestamp.isAfter(dayStart))
              .toList();
          final presentCount =
              todaysLogs.map((item) => item.studentId).toSet().length;
          final coveragePercent = totalStudents == 0
              ? 0
              : ((presentCount / totalStudents) * 100).round();

          return AppleInsetGroupedSection(
            header: 'Today\'s Attendance',
            children: [
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '$presentCount',
                          style: AppleTypography.tabularNumber(
                            fontSize: 38,
                            fontWeight: FontWeight.w700,
                            color: context.appColors.primaryText,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '/ $totalStudents checked in',
                          style: AppleTypography.headline.copyWith(
                            fontWeight: FontWeight.w500,
                            color: context.appColors.secondaryText,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: (context.appColors.success)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$coveragePercent%',
                            style: AppleTypography.footnote.copyWith(
                              fontWeight: FontWeight.w700,
                              color: context.appColors.success,
                              fontFeatures: AppleTypography.tabular,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        minHeight: 5,
                        value: totalStudents == 0
                            ? 0.0
                            : (presentCount / totalStudents).clamp(0.0, 1.0),
                        backgroundColor: context.appColors.border,
                        valueColor: AlwaysStoppedAnimation(context.appColors.blue),
                      ),
                    ),
                    const SizedBox(height: 18),
                    AppleTactileButton(
                      onPressed: kIsWeb
                          ? null
                          : () {
                              HapticFeedback.lightImpact();
                              context.push('/kiosk');
                            },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.camera_alt_rounded, size: 18),
                          SizedBox(width: 8),
                          Text('Start Kiosk Mode'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SessionsSection extends StatelessWidget {
  final List<SessionEntry> sessions;

  const _SessionsSection({required this.sessions});

  @override
  Widget build(BuildContext context) {
    final now = TimeOfDay.now();
    final nowMinutes = now.hour * 60 + now.minute;

    final liveSession = sessions.cast<SessionEntry?>().firstWhere(
          (s) =>
              s != null &&
              s.startMinuteOfDay <= nowMinutes &&
              s.endMinuteOfDay >= nowMinutes,
          orElse: () => null,
        );

    final upcomingSessions = sessions
        .where((s) => s.startMinuteOfDay > nowMinutes)
        .take(2)
        .toList();

    return AppleInsetGroupedSection(
      header: 'Timetable & Schedule',
      children: [
        if (liveSession != null)
          AppleListRow(
            leading: AppIconBadge(icon: Icons.sensors_rounded, tint: context.appColors.success),
            title: liveSession.title,
            subtitle: '${liveSession.room} · Active Window',
            trailing: Text(
              liveSession.timeLabel,
              style: AppleTypography.footnote.copyWith(
                fontWeight: FontWeight.w600,
                fontFeatures: AppleTypography.tabular,
              ),
            ),
            showChevron: true,
            onTap: () => context.push('/kiosk'),
          )
        else
          AppleListRow(
            leading: AppIconBadge(icon: Icons.calendar_today_rounded, tint: context.appColors.secondaryText),
            title: sessions.isEmpty ? 'No Scheduled Sessions' : 'Class Schedule',
            subtitle: sessions.isEmpty
                ? 'Tap to configure class attendance windows'
                : '${sessions.length} total sessions today',
            showChevron: true,
            onTap: () => context.go('/sessions'),
          ),
        for (final session in upcomingSessions)
          AppleListRow(
            leading: AppIconBadge(icon: Icons.schedule_rounded, tint: context.appColors.blue),
            title: session.title,
            subtitle: session.room,
            trailing: Text(
              session.timeLabel,
              style: AppleTypography.footnote.copyWith(
                color: context.appColors.secondaryText,
                fontFeatures: AppleTypography.tabular,
              ),
            ),
            showChevron: true,
            onTap: () => context.go('/sessions'),
          ),
      ],
    );
  }
}

class _NavigationSection extends StatelessWidget {
  const _NavigationSection();

  @override
  Widget build(BuildContext context) {
    return AppleInsetGroupedSection(
      header: 'Workspace',
      children: [
        AppleListRow(
          leading: AppIconBadge(icon: Icons.people_alt_rounded, tint: context.appColors.blue),
          title: 'Student Directory',
          subtitle: 'Enrolled students and facial profiles',
          showChevron: true,
          onTap: () => context.go('/students'),
        ),
        AppleListRow(
          leading: AppIconBadge(icon: Icons.history_rounded, tint: context.appColors.warning),
          title: 'Attendance Logs',
          subtitle: 'Chronological time-stamped check-ins',
          showChevron: true,
          onTap: () => context.push('/insights/logs'),
        ),
        AppleListRow(
          leading: AppIconBadge(icon: Icons.analytics_outlined, tint: context.appColors.success),
          title: 'Insights & Velocity',
          subtitle: 'Attendance rates and metrics',
          showChevron: true,
          onTap: () => context.go('/insights'),
        ),
        AppleListRow(
          leading: AppIconBadge(icon: Icons.admin_panel_settings_rounded, tint: context.appColors.secondaryText),
          title: 'Admin Terminal',
          subtitle: 'Registration and camera calibration',
          showChevron: true,
          onTap: () => context.go('/admin'),
        ),
      ],
    );
  }
}

class _SystemStatusSection extends StatelessWidget {
  const _SystemStatusSection();

  @override
  Widget build(BuildContext context) {
    return AppleInsetGroupedSection(
      header: 'System Telemetry',
      footer: 'Insight runs completely offline. No biometric vectors or facial images leave this device.',
      children: [
        AppleListRow(
          leading: AppIconBadge(icon: Icons.camera_alt_outlined, tint: context.appColors.success),
          title: 'Camera Inference',
          trailing: Text(
            kIsWeb ? 'Web Mode' : 'Online',
            style: AppleTypography.footnote.copyWith(
              fontWeight: FontWeight.w600,
              color: context.appColors.success,
            ),
          ),
        ),
        AppleListRow(
          leading: AppIconBadge(icon: Icons.shield_outlined, tint: context.appColors.blue),
          title: 'Storage & Encryption',
          trailing: Text(
            'Hive CE Local',
            style: AppleTypography.footnote.copyWith(
              color: context.appColors.secondaryText,
            ),
          ),
        ),
        AppleListRow(
          leading: AppIconBadge(icon: Icons.memory_rounded, tint: context.appColors.warning),
          title: 'Recognition Model',
          trailing: Text(
            'MobileFaceNet',
            style: AppleTypography.footnote.copyWith(
              color: context.appColors.secondaryText,
            ),
          ),
        ),
      ],
    );
  }
}
