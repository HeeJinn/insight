import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';
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
                color: const Color(0xFF1C1C1E),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF2C2C2E)),
              ),
              child: const Icon(
                Icons.event_note_rounded,
                size: 24,
                color: Color(0xFF8E8E93),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'No Check-in Records Yet',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Kiosk terminal live recognitions will appear here automatically in real time.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF8E8E93),
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
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
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: Color(0xFF8E8E93),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF242428)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF30D158).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Color(0xFF30D158),
              size: 18,
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
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C1E),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'ID $studentId',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF8E8E93),
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    if ((sessionTitle ?? '').isNotEmpty || (room ?? '').isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '${sessionTitle ?? 'Session'}${(room ?? '').isNotEmpty ? ' · ${room!}' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF7D7AFF),
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
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              timeLabel,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFFE5E5EA),
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

