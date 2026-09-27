import 'package:flutter_test/flutter_test.dart';
import 'package:insight/models/attendance.dart';
import 'package:insight/models/session_entry.dart';
import 'package:insight/models/student.dart';
import 'package:insight/services/session_clock.dart';
import 'package:insight/services/today_summary.dart';

void main() {
  final students = [
    Student(id: 's1', name: 'Maria Santos', embeddings: []),
    Student(id: 's2', name: 'John Dela Cruz', embeddings: []),
    Student(id: 's3', name: 'Ana Reyes', embeddings: []),
  ];
  const cs101 = SessionEntry(
    id: 'a',
    title: 'CS 101',
    room: '204',
    startMinuteOfDay: 9 * 60,
    endMinuteOfDay: 10 * 60 + 30,
    expected: 30,
  );
  const cs102 = SessionEntry(
    id: 'b',
    title: 'CS 102',
    room: '204',
    startMinuteOfDay: 13 * 60,
    endMinuteOfDay: 14 * 60,
    expected: 0,
  );
  DateTime at(int h, int m, {int day = 27}) => DateTime(2026, 9, day, h, m);

  group('TodaySummary', () {
    test('counts the running session, lateness and who is missing', () {
      final summary = TodaySummary.compute(
        students: students,
        sessions: const [cs101, cs102],
        now: at(9, 40),
        attendance: [
          Attendance(
            studentId: 's1',
            timestamp: at(9, 5),
            sessionTitle: 'CS 101',
            latencyMs: 300,
          ),
          Attendance(
            studentId: 's2',
            timestamp: at(9, 20),
            sessionTitle: 'CS 101',
            latencyMs: 500,
          ),
          // Yesterday: ignored.
          Attendance(
            studentId: 's3',
            timestamp: at(9, 5, day: 26),
            sessionTitle: 'CS 101',
          ),
        ],
      );

      expect(summary.active?.id, 'a');
      expect(summary.next?.id, 'b');
      expect(summary.presentNow, 2);
      expect(summary.expectedNow, 30);
      expect(summary.lateToday, 1, reason: '9:20 is past the 15-minute grace');
      expect(summary.checkedInToday, 2);
      expect(summary.averageScanMs, 400);
      expect(summary.notCheckedIn.map((s) => s.id), ['s3']);
      expect(
        summary.todaysRecords.first.studentId,
        's2',
        reason: 'newest first',
      );
    });

    test('between sessions nothing is "now" and everyone is listed', () {
      final summary = TodaySummary.compute(
        students: students,
        sessions: const [cs101, cs102],
        now: at(11, 0),
        attendance: [
          Attendance(
            studentId: 's1',
            timestamp: at(9, 5),
            sessionTitle: 'CS 101',
          ),
        ],
      );

      expect(summary.active, isNull);
      expect(summary.presentNow, 0);
      expect(summary.checkedInToday, 1);
      expect(summary.notCheckedIn, hasLength(3));
    });

    test(
      'with no schedule, general check-ins count and expected is everyone',
      () {
        final summary = TodaySummary.compute(
          students: students,
          sessions: const [],
          now: at(15, 0),
          attendance: [Attendance(studentId: 's2', timestamp: at(8, 0))],
        );

        expect(summary.presentNow, 1);
        expect(summary.expectedNow, 3);
        expect(summary.lateToday, 0);
        expect(summary.averageScanMs, isNull);
        expect(summary.notCheckedIn.map((s) => s.name), [
          'Ana Reyes',
          'Maria Santos',
        ], reason: 'sorted by name');
      },
    );
  });

  group('session_clock', () {
    test('formats times and ranges', () {
      expect(formatMinuteOfDay(0), '12:00 AM');
      expect(formatMinuteOfDay(9 * 60 + 2), '9:02 AM');
      expect(formatMinuteOfDay(12 * 60), '12:00 PM');
      expect(formatSessionRange(cs101), '9:00 – 10:30 AM');
      expect(
        formatSessionRange(
          const SessionEntry(
            id: 'c',
            title: 'x',
            room: '',
            startMinuteOfDay: 11 * 60,
            endMinuteOfDay: 12 * 60 + 30,
            expected: 0,
          ),
        ),
        '11:00 AM – 12:30 PM',
      );
    });

    test('late only after the grace period', () {
      expect(isLateFor(cs101, at(9, 15)), isFalse);
      expect(isLateFor(cs101, at(9, 16)), isTrue);
    });
  });
}
