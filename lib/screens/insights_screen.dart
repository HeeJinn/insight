import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/attendance.dart';
import '../models/student.dart';
import '../providers/hive_provider.dart';
import '../widgets/app_chrome.dart';
import '../widgets/responsive_utils.dart';

class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  String query = '';
  int rangeDays = 1;

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(studentsBoxProvider);
    final attendanceAsync = ref.watch(attendanceBoxProvider);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: AppBackground(
        child: studentsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(child: Text('Error: $error')),
          data: (studentsBox) => attendanceAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text('Error: $error')),
            data: (attendanceBox) => StreamBuilder(
              stream: attendanceBox.watch(),
              builder: (context, _) {
                final idToName = <String, String>{
                  for (final Student s in studentsBox.values) s.id: s.name,
                };

                final now = DateTime.now();
                final dayStart = DateTime(now.year, now.month, now.day);
                final rangeStart = dayStart.subtract(
                  Duration(days: rangeDays - 1),
                );
                final inRangeLogs = attendanceBox.values
                    .where((a) => !a.timestamp.isBefore(rangeStart))
                    .toList();
                final recentLogs = inRangeLogs.length;
                final uniqueToday = inRangeLogs.map((a) => a.studentId).toSet().length;
                final coverage = studentsBox.isEmpty
                    ? 0
                    : ((uniqueToday / studentsBox.length) * 100).round();

                final q = query.trim().toLowerCase();
                final filtered = attendanceBox.values.where((a) {
                  if (q.isEmpty) {
                    return !a.timestamp.isBefore(rangeStart);
                  }
                  final id = a.studentId.toLowerCase();
                  final name = (idToName[a.studentId] ?? '').toLowerCase();
                  final matchesStudent = id.contains(q) || name.contains(q);
                  return matchesStudent;
                }).toList()..sort((a, b) => b.timestamp.compareTo(a.timestamp));

                final trendDays = List<DateTime>.generate(
                  7,
                  (i) => dayStart.subtract(Duration(days: 6 - i)),
                );
                final trendCounts = trendDays.map((day) {
                  final next = day.add(const Duration(days: 1));
                  return attendanceBox.values
                      .where(
                        (a) =>
                            !a.timestamp.isBefore(day) && a.timestamp.isBefore(next),
                      )
                      .length;
                }).toList();

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final wide = width >= 1080;
                    final contentWidth = AppBreakpoints.contentWidth(width);
                    final padding = AppBreakpoints.pagePadding(width);
                    final bottomSafeGap = AppBreakpoints.navAwareBottomInset(
                      context,
                    );

                    return SafeArea(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: contentWidth),
                          child: CustomScrollView(
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            slivers: [
                              SliverPadding(
                                padding: padding.copyWith(bottom: bottomSafeGap),
                                sliver: SliverList.list(
                                  children: [
                                    _TopTitleBar(
                                      canPop: context.canPop(),
                                      rangeDays: rangeDays,
                                      onRangeChanged: (value) =>
                                          setState(() => rangeDays = value),
                                    ),
                                    const SizedBox(height: 16),
                                    AppPanel(
                                      radius: 22,
                                      padding: const EdgeInsets.all(14),
                                      child: SearchBar(
                                        hintText: 'Search by student name or ID',
                                        leading: const Icon(Icons.search),
                                        onChanged: (value) =>
                                            setState(() => query = value),
                                        backgroundColor: WidgetStatePropertyAll(
                                          Theme.of(
                                            context,
                                          ).colorScheme.surfaceContainerHighest,
                                        ),
                                        shape: WidgetStatePropertyAll(
                                          RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    _KpiStrip(
                                      wide: wide,
                                      students: studentsBox.length,
                                      logsInRange: recentLogs,
                                      coverage: coverage,
                                      rangeDays: rangeDays,
                                    ),
                                    const SizedBox(height: 18),
                                    _TrendCard(
                                      dayCounts: trendCounts,
                                      coverage: coverage,
                                      logsInRange: recentLogs,
                                      rangeDays: rangeDays,
                                    ),
                                    const SizedBox(height: 18),
                                    AppPanel(
                                      radius: 22,
                                      child: _RecentActivityList(
                                        logs: filtered,
                                        idToName: idToName,
                                        emptyMessage: attendanceBox.isEmpty
                                            ? 'No attendance has been logged yet.'
                                            : filtered.isEmpty && q.isNotEmpty
                                            ? 'No check-ins match your search.'
                                            : 'No check-ins for this filter.',
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton.icon(
                                        onPressed: () =>
                                            context.push('/insights/logs'),
                                        icon: const Icon(Icons.open_in_new),
                                        label: const Text('View all check-ins'),
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
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final surfaceAlt = Theme.of(context).colorScheme.surfaceContainerHighest;
    return AppPanel(
      radius: 20,
      color: surfaceAlt,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: Theme.of(
                    context,
                  ).textTheme.headlineMedium?.copyWith(
                    fontSize: 32,
                    fontWeight: FontWeight.w600,
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

class _RecentActivityList extends StatelessWidget {
  final List<Attendance> logs;
  final Map<String, String> idToName;
  final String emptyMessage;

  const _RecentActivityList({
    required this.logs,
    required this.idToName,
    required this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = [...logs]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Recent check-ins',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Text(
              'Latest 5',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (sorted.isEmpty)
          Text(
            emptyMessage.isNotEmpty
                ? emptyMessage
                : 'No attendance has been logged yet.',
            style: Theme.of(context).textTheme.bodyMedium,
          )
        else
          ...sorted
              .take(5)
              .map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppPanel(
                    radius: 20,
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    elevated: false,
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.fingerprint,
                          color: Colors.teal,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                idToName[item.studentId] ?? 'Unknown student',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                'ID ${item.studentId} • ${_dayLabel(item.timestamp)}',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${item.timestamp.hour.toString().padLeft(2, '0')}:${item.timestamp.minute.toString().padLeft(2, '0')}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ],
    );
  }
}

class _TopTitleBar extends StatelessWidget {
  final bool canPop;
  final int rangeDays;
  final ValueChanged<int> onRangeChanged;

  const _TopTitleBar({
    required this.canPop,
    required this.rangeDays,
    required this.onRangeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (canPop) ...[
              IconButton.filledTonal(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Insights',
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Attendance performance and student activity',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            IconButton.filledTonal(
              onPressed: () => context.push('/privacy'),
              icon: const Icon(Icons.privacy_tip_outlined),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 1, label: Text('Today')),
            ButtonSegment(value: 7, label: Text('7d')),
            ButtonSegment(value: 30, label: Text('30d')),
          ],
          selected: {rangeDays},
          onSelectionChanged: (selection) => onRangeChanged(selection.first),
        ),
      ],
    );
  }
}

class _KpiStrip extends StatelessWidget {
  final bool wide;
  final int students;
  final int logsInRange;
  final int coverage;
  final int rangeDays;

  const _KpiStrip({
    required this.wide,
    required this.students,
    required this.logsInRange,
    required this.coverage,
    required this.rangeDays,
  });

  @override
  Widget build(BuildContext context) {
    return wide
        ? Row(
            children: [
              Expanded(
                child: _MetricCard(
                  title: 'Students',
                  value: '$students',
                  color: Theme.of(context).colorScheme.primary,
                  icon: Icons.groups_2_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  title: rangeDays == 1 ? 'Logs Today' : 'Logs ($rangeDays d)',
                  value: '$logsInRange',
                  color: Theme.of(context).colorScheme.secondary,
                  icon: Icons.event_note_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  title: 'Coverage',
                  value: '$coverage%',
                  color: Theme.of(context).colorScheme.tertiary,
                  icon: Icons.query_stats_outlined,
                ),
              ),
            ],
          )
        : Column(
            children: [
              _MetricCard(
                title: 'Students',
                value: '$students',
                color: Theme.of(context).colorScheme.primary,
                icon: Icons.groups_2_outlined,
              ),
              const SizedBox(height: 12),
              _MetricCard(
                title: rangeDays == 1 ? 'Logs Today' : 'Logs ($rangeDays d)',
                value: '$logsInRange',
                color: Theme.of(context).colorScheme.secondary,
                icon: Icons.event_note_outlined,
              ),
              const SizedBox(height: 12),
              _MetricCard(
                title: 'Coverage',
                value: '$coverage%',
                color: Theme.of(context).colorScheme.tertiary,
                icon: Icons.query_stats_outlined,
              ),
            ],
          );
  }
}

class _TrendCard extends StatelessWidget {
  final List<int> dayCounts;
  final int coverage;
  final int logsInRange;
  final int rangeDays;

  const _TrendCard({
    required this.dayCounts,
    required this.coverage,
    required this.logsInRange,
    required this.rangeDays,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final maxCount = dayCounts.fold<int>(1, (a, b) => b > a ? b : a);
    final last = dayCounts.isNotEmpty ? dayCounts.last : 0;
    final prev = dayCounts.length > 1 ? dayCounts[dayCounts.length - 2] : 0;
    final delta = last - prev;
    return AppPanel(
      radius: 22,
      color: cs.surfaceContainerHigh,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Weekly trend',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              _DeltaChip(delta: delta),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$logsInRange check-ins in selected range • $coverage% coverage',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < dayCounts.length; i++) ...[
                Expanded(
                  child: _DayBar(
                    value: dayCounts[i],
                    maxValue: maxCount,
                    label: i == dayCounts.length - 1 ? 'Today' : 'D-${6 - i}',
                  ),
                ),
                if (i != dayCounts.length - 1) const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Text(
            rangeDays == 1
                ? 'Viewing today only. Switch to 7d or 30d for trend-driven decisions.'
                : 'Use this trend to spot low-attendance days and follow up quickly.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _DeltaChip extends StatelessWidget {
  final int delta;

  const _DeltaChip({required this.delta});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final positive = delta >= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (positive ? cs.primary : cs.error).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '${positive ? '+' : ''}$delta vs yesterday',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: positive ? cs.primary : cs.error,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DayBar extends StatelessWidget {
  final int value;
  final int maxValue;
  final String label;

  const _DayBar({
    required this.value,
    required this.maxValue,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final heightFactor = maxValue == 0 ? 0.0 : value / maxValue;
    return Column(
      children: [
        Text('$value', style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 8),
        Container(
          height: 84,
          alignment: Alignment.bottomCenter,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: value == 0
              ? null
              : FractionallySizedBox(
                  heightFactor: heightFactor.clamp(0.08, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: cs.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

String _dayLabel(DateTime value) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final date = DateTime(value.year, value.month, value.day);
  if (date == today) {
    return 'Today';
  }
  if (date == today.subtract(const Duration(days: 1))) {
    return 'Yesterday';
  }
  return '${value.month}/${value.day}';
}
