import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';
import '../app_theme.dart';
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
        ? const _LogsEmptyState(
            title: 'No attendance records yet',
            subtitle:
                'Kiosk mode will create the first entry once a student is recognized.',
          )
        : ListView.separated(
            padding: const EdgeInsets.only(bottom: 8),
            itemCount: logs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final log = logs[index];
              final student = studentsBox.get(log.studentId);
              return _AttendanceTile(
                studentName: student?.name ?? 'Unknown student',
                studentId: log.studentId,
                timestamp: log.timestamp.toLocal().toString().split('.').first,
                sessionTitle: log.sessionTitle,
                room: log.room,
              );
            },
          );
  }
}

class _LogsEmptyState extends StatelessWidget {
  final String title;
  final String subtitle;

  const _LogsEmptyState({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: AppPanel(
                radius: 28,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                elevated: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        gradient: AppTheme.accentGradient,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: AppTheme.panelShadow,
                      ),
                      child: const Icon(
                        Icons.event_busy_outlined,
                        size: 32,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AttendanceTile extends StatelessWidget {
  final String studentName;
  final String studentId;
  final String timestamp;
  final String? sessionTitle;
  final String? room;

  const _AttendanceTile({
    required this.studentName,
    required this.studentId,
    required this.timestamp,
    this.sessionTitle,
    this.room,
  });

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      radius: 14,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.all(12),
      elevated: false,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.accentSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.check_rounded, color: AppTheme.accentDark),
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
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppTheme.muted),
                ),
                if ((sessionTitle ?? '').isNotEmpty || (room ?? '').isNotEmpty)
                  Text(
                    '${sessionTitle ?? 'Session'}${(room ?? '').isNotEmpty ? ' • ${room!}' : ''}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppTheme.accentDark),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 126,
            child: Text(
              timestamp,
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
  }
}
