import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';
import '../models/attendance.dart';
import '../models/student.dart';
import 'app_chrome.dart';

class AttendanceLogs extends StatelessWidget {
  final Box<Attendance> attendanceBox;
  final Box<Student> studentsBox;

  const AttendanceLogs({
    super.key,
    required this.attendanceBox,
    required this.studentsBox,
  });

  @override
  Widget build(BuildContext context) {
    final logs = attendanceBox.values.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return logs.isEmpty
        ? const AppEmptyState(
            icon: Icons.event_busy_outlined,
            title: 'No attendance records yet',
            subtitle: 'Kiosk mode creates the first entry after a recognition.',
          )
        : ListView.separated(
            padding: const EdgeInsets.only(bottom: 8),
            itemCount: logs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final log = logs[index];
              final student = studentsBox.get(log.studentId);
              final date = DateTime(
                log.timestamp.year,
                log.timestamp.month,
                log.timestamp.day,
              );
              final previousDate = index == 0
                  ? null
                  : DateTime(
                      logs[index - 1].timestamp.year,
                      logs[index - 1].timestamp.month,
                      logs[index - 1].timestamp.day,
                    );
              final showHeader = previousDate == null || date != previousDate;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showHeader)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        _humanDayLabel(log.timestamp),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  _AttendanceTile(
                    studentName: student?.name ?? 'Unknown student',
                    studentId: log.studentId,
                    timeLabel: _timeLabel(log.timestamp),
                    sessionTitle: log.sessionTitle,
                    room: log.room,
                  ),
                ],
              );
            },
          );
  }

  String _timeLabel(DateTime d) {
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  String _humanDayLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(d.year, d.month, d.day);
    if (date == today) return 'Today';
    if (date == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}

class _AttendanceTile extends StatelessWidget {
  final String studentName;
  final String studentId;
  final String timeLabel;
  final String? sessionTitle;
  final String? room;

  const _AttendanceTile({
    required this.studentName,
    required this.studentId,
    required this.timeLabel,
    this.sessionTitle,
    this.room,
  });

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      radius: 16,
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      padding: const EdgeInsets.all(12),
      elevated: false,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.check_rounded,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  studentName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  'ID $studentId',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                if ((sessionTitle ?? '').isNotEmpty || (room ?? '').isNotEmpty)
                  Text(
                    '${sessionTitle ?? 'Session'}${(room ?? '').isNotEmpty ? ' • ${room!}' : ''}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 78,
            child: Text(
              timeLabel,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
