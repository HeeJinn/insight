import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import '../app_theme.dart';
import '../core/widgets/core_widgets.dart';
import '../providers/hive_provider.dart';
import '../widgets/app_chrome.dart';
import '../widgets/responsive_utils.dart';

class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  int rangeDays = 1; // 1: Today, 7: 7D, 30: 30D, 0: All
  String query = '';

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(studentsBoxProvider);
    final attendanceAsync = ref.watch(attendanceBoxProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: AppBackground(
        child: AppAsyncView.combine2(
          a: studentsAsync,
          b: attendanceAsync,
          data: (context, studentsBox, attendanceBox) {
            // Box providers only resolve once; without watching the boxes
            // directly, newly logged attendance (e.g. from a kiosk scan on
            // another screen) wouldn't show up here until something else
            // happened to trigger a rebuild.
            return StreamBuilder(
              stream: studentsBox.watch(),
              builder: (context, _) => StreamBuilder(
                stream: attendanceBox.watch(),
                builder: (context, _) {
                  final idToName = {
                    for (final s in studentsBox.values) s.id: s.name,
                  };

                  final now = DateTime.now();
                  final dayStart = DateTime(now.year, now.month, now.day);
                  final rangeStart = rangeDays == 0
                      ? DateTime.fromMillisecondsSinceEpoch(0)
                      : (rangeDays == 1
                            ? dayStart
                            : now.subtract(Duration(days: rangeDays)));

                  final inRangeLogs = attendanceBox.values
                      .where((a) => !a.timestamp.isBefore(rangeStart))
                      .toList();
                  final recentLogs = inRangeLogs.length;
                  final uniqueStudents = inRangeLogs
                      .map((a) => a.studentId)
                      .toSet()
                      .length;
                  final coverage = studentsBox.isEmpty
                      ? 0
                      : ((uniqueStudents / studentsBox.length) * 100).round();
                  final timedLogs = inRangeLogs
                      .map((a) => a.latencyMs)
                      .whereType<int>()
                      .toList();
                  final averageLatencyMs = timedLogs.isEmpty
                      ? null
                      : (timedLogs.reduce((a, b) => a + b) / timedLogs.length)
                            .round();

                  final q = query.trim().toLowerCase();
                  final filtered =
                      attendanceBox.values.where((a) {
                          if (q.isEmpty) {
                            return !a.timestamp.isBefore(rangeStart);
                          }
                          final id = a.studentId.toLowerCase();
                          final name = (idToName[a.studentId] ?? '')
                              .toLowerCase();
                          return id.contains(q) || name.contains(q);
                        }).toList()
                        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

                  final trendDays = List<DateTime>.generate(
                    7,
                    (i) => dayStart.subtract(Duration(days: 6 - i)),
                  );
                  final trendCounts = trendDays.map((day) {
                    final next = day.add(const Duration(days: 1));
                    return attendanceBox.values
                        .where(
                          (a) =>
                              !a.timestamp.isBefore(day) &&
                              a.timestamp.isBefore(next),
                        )
                        .length;
                  }).toList();

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final contentWidth = AppBreakpoints.contentWidth(
                        constraints.maxWidth,
                      );
                      final padding = AppBreakpoints.pagePadding(
                        constraints.maxWidth,
                      );

                      return SafeArea(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: contentWidth),
                            child: ListView(
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              padding: padding.copyWith(
                                bottom: AppBreakpoints.navAwareBottomInset(
                                  context,
                                ),
                              ),
                              children: [
                                // Header & Segmented control
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 4,
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      if (context.canPop()) ...[
                                        IconButton(
                                          icon: const Icon(
                                            Icons.arrow_back_ios_new_rounded,
                                            size: 20,
                                          ),
                                          onPressed: () => context.pop(),
                                        ),
                                        const SizedBox(width: 4),
                                      ],
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'ANALYTICS',
                                              style: AppleTypography.caption1
                                                  .copyWith(
                                                    fontWeight: FontWeight.w600,
                                                    letterSpacing: 0.8,
                                                    color: context
                                                        .appColors
                                                        .secondaryText,
                                                  ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Insights',
                                              style: AppleTypography.largeTitle
                                                  .copyWith(
                                                    color: context
                                                        .appColors
                                                        .primaryText,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.history_rounded),
                                        tooltip: 'All Logs',
                                        onPressed: () =>
                                            context.push('/insights/logs'),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Apple Segmented Control for timeframes
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  child: CupertinoSlidingSegmentedControl<int>(
                                    groupValue: rangeDays,
                                    backgroundColor: isDark
                                        ? context.appColors.surface
                                        : const Color(0xFFE5E5EA),
                                    thumbColor: isDark
                                        ? context.appColors.elevatedSurface
                                        : Colors.white,
                                    children: const {
                                      1: Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        child: Text('Today'),
                                      ),
                                      7: Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        child: Text('7 Days'),
                                      ),
                                      30: Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        child: Text('30 Days'),
                                      ),
                                      0: Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        child: Text('All'),
                                      ),
                                    },
                                    onValueChanged: (value) {
                                      if (value != null) {
                                        HapticFeedback.selectionClick();
                                        setState(() => rangeDays = value);
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(height: 18),

                                // Inset Grouped Section for Metric Statistics
                                AppleInsetGroupedSection(
                                  header: 'Key Metrics',
                                  children: [
                                    AppleListRow(
                                      leading: AppIconBadge(
                                        icon: Icons.people_alt_rounded,
                                        tint: context.appColors.blue,
                                        size: 32,
                                      ),
                                      title: 'Enrolled Students',
                                      subtitle:
                                          'Total biometric identities registered',
                                      trailing: Text(
                                        '${studentsBox.length}',
                                        style: AppleTypography.tabularNumber(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                          color: context.appColors.primaryText,
                                        ),
                                      ),
                                    ),
                                    AppleListRow(
                                      leading: AppIconBadge(
                                        icon: Icons.check_circle_rounded,
                                        tint: context.appColors.success,
                                        size: 32,
                                      ),
                                      title: 'Check-ins in Range',
                                      subtitle: rangeDays == 1
                                          ? 'Scanned today'
                                          : 'Total events over selected timeframe',
                                      trailing: Text(
                                        '$recentLogs',
                                        style: AppleTypography.tabularNumber(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                          color: context.appColors.primaryText,
                                        ),
                                      ),
                                    ),
                                    AppleListRow(
                                      leading: AppIconBadge(
                                        icon: Icons.pie_chart_rounded,
                                        tint: context.appColors.warning,
                                        size: 32,
                                      ),
                                      title: 'Attendance Coverage',
                                      subtitle:
                                          '$uniqueStudents of ${studentsBox.length} students',
                                      trailing: Text(
                                        '$coverage%',
                                        style: AppleTypography.tabularNumber(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                          color: context.appColors.primaryText,
                                        ),
                                      ),
                                    ),
                                    AppleListRow(
                                      leading: AppIconBadge(
                                        icon: Icons.timer_outlined,
                                        tint: context.appColors.accent,
                                        size: 32,
                                      ),
                                      title: 'Avg. Recognition Time',
                                      subtitle: timedLogs.isEmpty
                                          ? 'No timed check-ins yet'
                                          : 'Capture to log, ${timedLogs.length} timed check-ins',
                                      trailing: Text(
                                        averageLatencyMs == null
                                            ? '-'
                                            : '$averageLatencyMs ms',
                                        style: AppleTypography.tabularNumber(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                          color: context.appColors.primaryText,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                // 7-Day Velocity Activity Chart
                                AppleInsetGroupedSection(
                                  header: '7-Day Activity Velocity',
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 16,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              for (int i = 0; i < 7; i++) ...[
                                                _DayBar(
                                                  dayLabel: _weekdayShort(
                                                    trendDays[i].weekday,
                                                  ),
                                                  count: trendCounts[i],
                                                  maxCount: trendCounts.fold(
                                                    1,
                                                    (m, c) => c > m ? c : m,
                                                  ),
                                                  isToday: i == 6,
                                                  maxBarHeight:
                                                      AppBreakpoints.isCompact(
                                                        constraints.maxWidth,
                                                      )
                                                      ? 70
                                                      : 120,
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                // Search audit logs by student name or ID
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  child: SearchBar(
                                    hintText: 'Search by name or student ID',
                                    leading: const Icon(
                                      Icons.search_rounded,
                                      size: 20,
                                    ),
                                    trailing: query.isEmpty
                                        ? null
                                        : [
                                            IconButton(
                                              icon: const Icon(
                                                Icons.close_rounded,
                                                size: 18,
                                              ),
                                              tooltip: 'Clear search',
                                              onPressed: () =>
                                                  setState(() => query = ''),
                                            ),
                                          ],
                                    onChanged: (value) =>
                                        setState(() => query = value),
                                  ),
                                ),
                                const SizedBox(height: 18),

                                // Inset Grouped Section for Recent Activity Feed
                                AppleInsetGroupedSection(
                                  header: query.isEmpty
                                      ? 'Recent Audit Logs'
                                      : 'Search Results',
                                  footer:
                                      'Tap any row to view full timestamp metadata',
                                  children: [
                                    if (filtered.isEmpty)
                                      Padding(
                                        padding: const EdgeInsets.all(24.0),
                                        child: Center(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              // "Empty State" by Creative Salt &
                                              // Pepper, via LottieFiles (Lottie
                                              // Simple License).
                                              SizedBox(
                                                width: 96,
                                                height: 96,
                                                child: Lottie.asset(
                                                  'assets/animations/empty_state.json',
                                                  repeat: true,
                                                  fit: BoxFit.contain,
                                                  errorBuilder:
                                                      (
                                                        context,
                                                        error,
                                                        stackTrace,
                                                      ) =>
                                                          const SizedBox.shrink(),
                                                ),
                                              ),
                                              Text(
                                                query.isEmpty
                                                    ? 'No check-ins recorded for this timeframe.'
                                                    : 'No check-ins match "$query".',
                                                style: AppleTypography.subhead
                                                    .copyWith(
                                                      color: context
                                                          .appColors
                                                          .secondaryText,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      )
                                    else
                                      for (final log in filtered.take(6))
                                        AppleListRow(
                                          leading: AppIconBadge(
                                            icon: Icons.check_rounded,
                                            tint: context.appColors.success,
                                            size: 32,
                                          ),
                                          title:
                                              idToName[log.studentId] ??
                                              'Unknown Student',
                                          subtitle:
                                              'ID ${log.studentId} · ${_dayLabel(log.timestamp)}',
                                          trailing: Text(
                                            '${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}',
                                            style: AppleTypography.footnote
                                                .copyWith(
                                                  fontWeight: FontWeight.w600,
                                                  fontFeatures:
                                                      AppleTypography.tabular,
                                                  color: context
                                                      .appColors
                                                      .secondaryText,
                                                ),
                                          ),
                                          onTap: () =>
                                              context.push('/insights/logs'),
                                        ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  String _weekdayShort(int weekday) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[(weekday - 1).clamp(0, 6)];
  }

  String _dayLabel(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return 'Today';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (dt.year == yesterday.year &&
        dt.month == yesterday.month &&
        dt.day == yesterday.day) {
      return 'Yesterday';
    }
    return '${dt.month}/${dt.day}';
  }
}

class _DayBar extends StatelessWidget {
  final String dayLabel;
  final int count;
  final int maxCount;
  final bool isToday;
  final double maxBarHeight;

  const _DayBar({
    required this.dayLabel,
    required this.count,
    required this.maxCount,
    required this.isToday,
    this.maxBarHeight = 70,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ratio = maxCount == 0 ? 0.0 : (count / maxCount).clamp(0.08, 1.0);
    final barColor = isToday
        ? (context.appColors.blue)
        : (isDark
              ? context.appColors.elevatedSurface
              : const Color(0xFFE5E5EA));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$count',
          style: AppleTypography.caption2.copyWith(
            fontWeight: FontWeight.w600,
            fontFeatures: AppleTypography.tabular,
            color: context.appColors.secondaryText,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 28,
          height: maxBarHeight * ratio,
          decoration: BoxDecoration(
            color: barColor,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          dayLabel,
          style: AppleTypography.caption2.copyWith(
            fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
            color: isToday
                ? (context.appColors.blue)
                : (context.appColors.secondaryText),
          ),
        ),
      ],
    );
  }
}
