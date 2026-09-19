import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';
import '../app_theme.dart';
import '../models/attendance.dart';
import '../models/student.dart';

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

    if (logs.isEmpty) {
      final colors = context.appColors;
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: colors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: colors.border),
              ),
              child: Icon(
                Icons.event_note_rounded,
                size: 24,
                color: colors.mutedText,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'No Check-in Records Yet',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: colors.primaryText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Kiosk terminal live recognitions will appear here automatically in real time.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: colors.mutedText,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: logs.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
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
                padding: const EdgeInsets.only(left: 4, top: 4, bottom: 6),
                child: Text(
                  _humanDayLabel(log.timestamp).toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: context.appColors.mutedText,
                  ),
                ),
              ),
            _AppleAttendanceRow(
              studentName: student?.name ?? 'Unknown Student',
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

class _AppleAttendanceRow extends StatelessWidget {
  final String studentName;
  final String studentId;
  final String timeLabel;
  final String? sessionTitle;
  final String? room;

  const _AppleAttendanceRow({
    required this.studentName,
    required this.studentId,
    required this.timeLabel,
    this.sessionTitle,
    this.room,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.elevatedSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: colors.success.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.check_rounded, color: colors.success, size: 18),
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
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: colors.primaryText,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'ID $studentId',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: colors.mutedText,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    if ((sessionTitle ?? '').isNotEmpty ||
                        (room ?? '').isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '${sessionTitle ?? 'Session'}${(room ?? '').isNotEmpty ? ' · ${room!}' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.accent,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              timeLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: colors.secondaryText,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
