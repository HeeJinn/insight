import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../app_theme.dart';
import '../models/attendance.dart';
import '../models/student.dart';
import '../providers/hive_provider.dart';
import '../widgets/app_chrome.dart';

class InsightLogsScreen extends ConsumerStatefulWidget {
  const InsightLogsScreen({super.key});

  @override
  ConsumerState<InsightLogsScreen> createState() => _InsightLogsScreenState();
}

class _InsightLogsScreenState extends ConsumerState<InsightLogsScreen> {
  String _query = '';
  bool _todayOnly = true;

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(studentsBoxProvider);
    final attendanceAsync = ref.watch(attendanceBoxProvider);

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () => context.canPop() ? context.pop() : context.go('/insights'),
        ),
        title: const Text('All check-ins'),
      ),
      body: AppBackground(
        child: studentsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (studentsBox) => attendanceAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (attendanceBox) => StreamBuilder(
              stream: attendanceBox.watch(),
              builder: (context, _) {
              final idToName = <String, String>{
                for (final Student s in studentsBox.values) s.id: s.name,
              };
              final now = DateTime.now();
              final dayStart = DateTime(now.year, now.month, now.day);
              final q = _query.trim().toLowerCase();

              final filtered = attendanceBox.values.where((Attendance a) {
                if (q.isEmpty) {
                  return !_todayOnly || a.timestamp.isAfter(dayStart);
                }
                final id = a.studentId.toLowerCase();
                final name = (idToName[a.studentId] ?? '').toLowerCase();
                return id.contains(q) || name.contains(q);
              }).toList()
                ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: SearchBar(
                      hintText: 'Search by student name or ID',
                      leading: const Icon(Icons.search),
                      onChanged: (v) => setState(() => _query = v),
                      backgroundColor: WidgetStatePropertyAll(
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                      ),
                      elevation: const WidgetStatePropertyAll(0),
                      side: const WidgetStatePropertyAll(
                        BorderSide(color: AppTheme.border),
                      ),
                      shape: WidgetStatePropertyAll(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      constraints: const BoxConstraints(minHeight: 52),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: q.isEmpty
                          ? FilterChip(
                              label: const Text('Today only'),
                              selected: _todayOnly,
                              onSelected: (v) => setState(() => _todayOnly = v),
                            )
                          : Text(
                              'All dates for matches',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppTheme.muted),
                            ),
                    ),
                  ),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Text(
                              q.isEmpty
                                  ? 'No logs yet.'
                                  : 'No logs match your search.',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, i) {
                              final item = filtered[i];
                              final name =
                                  idToName[item.studentId] ?? 'Unknown student';
                              return AppPanel(
                                radius: 14,
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.fingerprint),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium,
                                          ),
                                          Text(
                                            'ID ${item.studentId}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: AppTheme.muted,
                                                ),
                                          ),
                                          if ((item.sessionTitle ?? '').isNotEmpty ||
                                              (item.room ?? '').isNotEmpty)
                                            Text(
                                              '${item.sessionTitle ?? 'Session'}'
                                              '${(item.room ?? '').isNotEmpty ? ' • ${item.room!}' : ''}',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color: AppTheme.accentDark,
                                                  ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        minWidth: 110,
                                        maxWidth: 132,
                                      ),
                                      child: Text(
                                        item.timestamp
                                            .toLocal()
                                            .toString()
                                            .split('.')
                                            .first,
                                        textAlign: TextAlign.right,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(color: AppTheme.muted),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
              },
            ),
          ),
        ),
      ),
    );
  }
}
