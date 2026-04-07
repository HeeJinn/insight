import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../app_theme.dart';
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
  bool todayOnly = true;

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(studentsBoxProvider);
    final attendanceAsync = ref.watch(attendanceBoxProvider);

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: const Text('Insights'),
        actions: [
          IconButton(
            onPressed: () => context.push('/privacy'),
            icon: const Icon(Icons.privacy_tip_outlined),
          ),
        ],
      ),
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
              final recentLogs = attendanceBox.values
                  .where((a) => a.timestamp.isAfter(dayStart))
                  .length;
              final uniqueToday = attendanceBox.values
                  .where((a) => a.timestamp.isAfter(dayStart))
                  .map((a) => a.studentId)
                  .toSet()
                  .length;
              final coverage = studentsBox.isEmpty
                  ? 0
                  : ((uniqueToday / studentsBox.length) * 100).round();

              final q = query.trim().toLowerCase();
              final filtered = attendanceBox.values.where((a) {
                if (q.isEmpty) {
                  return !todayOnly || a.timestamp.isAfter(dayStart);
                }
                // Name or ID search: show all logs for matching students (ignore "today" when searching).
                final id = a.studentId.toLowerCase();
                final name = (idToName[a.studentId] ?? '').toLowerCase();
                final matchesStudent =
                    id.contains(q) || name.contains(q);
                return matchesStudent;
              }).toList()
                ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

              return LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final wide = width >= 1080;
                  final contentWidth = AppBreakpoints.contentWidth(width);
                  final padding = AppBreakpoints.pagePadding(width);

                  return SafeArea(
                    child: SingleChildScrollView(
                      padding: padding,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: contentWidth),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const AppPanel(
                                child: AppSectionHeading(
                                  eyebrow: 'Performance overview',
                                  title: 'Insights',
                                  subtitle:
                                      'Track attendance velocity, daily coverage, and top recent activity.',
                                  compact: false,
                                ),
                              ),
                              const SizedBox(height: 18),
                              wide
                                  ? Row(
                                      children: [
                                        Expanded(
                                          child: _MetricCard(
                                            title: 'Students',
                                            value: '${studentsBox.length}',
                                            color: AppTheme.blue,
                                            icon: Icons.groups_2_outlined,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: _MetricCard(
                                            title: 'Logs Today',
                                            value: '$recentLogs',
                                            color: AppTheme.accentDark,
                                            icon: Icons.flash_on_outlined,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: _MetricCard(
                                            title: 'Coverage',
                                            value: '$coverage%',
                                            color: AppTheme.success,
                                            icon: Icons.query_stats_outlined,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Column(
                                      children: [
                                        _MetricCard(
                                          title: 'Students',
                                          value: '${studentsBox.length}',
                                          color: AppTheme.blue,
                                          icon: Icons.groups_2_outlined,
                                        ),
                                        const SizedBox(height: 12),
                                        _MetricCard(
                                          title: 'Logs Today',
                                          value: '$recentLogs',
                                          color: AppTheme.accentDark,
                                          icon: Icons.flash_on_outlined,
                                        ),
                                        const SizedBox(height: 12),
                                        _MetricCard(
                                          title: 'Coverage',
                                          value: '$coverage%',
                                          color: AppTheme.success,
                                          icon: Icons.query_stats_outlined,
                                        ),
                                      ],
                                    ),
                              const SizedBox(height: 18),
                              AppPanel(
                                radius: 18,
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  children: [
                                    SearchBar(
                                      hintText: 'Search by student name or ID',
                                      leading: const Icon(Icons.search),
                                      onChanged: (value) => setState(() => query = value),
                                      backgroundColor: WidgetStatePropertyAll(
                                        Theme.of(context).colorScheme.surfaceContainerHighest,
                                      ),
                                      shape: WidgetStatePropertyAll(
                                        RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    if (q.isEmpty)
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: FilterChip(
                                          label: const Text('Today only'),
                                          selected: todayOnly,
                                          onSelected: (v) =>
                                              setState(() => todayOnly = v),
                                        ),
                                      )
                                    else
                                      Text(
                                        'Showing all dates for name or ID matches.',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(color: AppTheme.muted),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),
                              AppPanel(
                                child: _RecentActivityList(
                                  logs: filtered,
                                  idToName: idToName,
                                  emptyMessage: attendanceBox.isEmpty
                                      ? 'No attendance has been logged yet.'
                                      : filtered.isEmpty && q.isNotEmpty
                                          ? 'No check-ins match your search.'
                                          : filtered.isEmpty
                                              ? 'No check-ins for this filter.'
                                              : '',
                                ),
                              ),
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: () => context.push('/insights/logs'),
                                  icon: const Icon(Icons.open_in_new),
                                  label: const Text('View all check-ins'),
                                ),
                              ),
                            ],
                          ),
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
    final tone = Theme.of(context).colorScheme.surfaceContainerHighest;
    return AppPanel(
      color: tone,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
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
                Text(value, style: Theme.of(context).textTheme.headlineMedium),
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
        Text('Recent check-ins', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        if (sorted.isEmpty)
          Text(
            emptyMessage.isNotEmpty
                ? emptyMessage
                : 'No attendance has been logged yet.',
            style: Theme.of(context).textTheme.bodyMedium,
          )
        else
          ...sorted.take(5).map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppPanel(
                radius: 20,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                elevated: false,
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Icon(
                      Icons.fingerprint,
                      color: AppTheme.accentDark,
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
                            'ID ${item.studentId}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppTheme.muted),
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
