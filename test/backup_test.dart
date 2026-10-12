import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:insight/models/attendance.dart';
import 'package:insight/models/session_entry.dart';
import 'package:insight/models/student.dart';
import 'package:insight/services/backup.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/test_app.dart';

void main() {
  final backup = Backup(
    createdAt: DateTime(2026, 10, 13, 9, 30),
    students: [
      Student(
        id: 's1',
        name: 'Maria Santos',
        embeddings: [
          [0.25, -0.5],
        ],
        enrolledAt: DateTime(2026, 9, 1, 8),
      ),
    ],
    attendance: [
      Attendance(
        studentId: 's1',
        timestamp: DateTime(2026, 10, 13, 9, 5),
        sessionTitle: 'CS 101',
        latencyMs: 300,
        matchDistance: 0.42,
        matchMargin: double.infinity,
      ),
      Attendance(
        studentId: 's1',
        timestamp: DateTime(2026, 10, 12, 9),
        excused: true,
      ),
    ],
    sessions: const [
      SessionEntry(
        id: 'a',
        title: 'CS 101',
        room: '204',
        startMinuteOfDay: 540,
        endMinuteOfDay: 630,
        expected: 0,
        studentIds: {'s1'},
      ),
    ],
  );

  test('round-trips students, check-ins and sessions', () {
    final back = Backup.decode(backup.encode());
    expect(back.createdAt, backup.createdAt);
    expect(back.students.single.embeddings, [
      [0.25, -0.5],
    ]);
    expect(back.students.single.enrolledAt, DateTime(2026, 9, 1, 8));
    final first = back.attendance.first;
    expect(first.sessionTitle, 'CS 101');
    expect(first.matchDistance, 0.42);
    expect(first.matchMargin, isNull, reason: 'JSON has no infinity');
    expect(back.attendance.last.excused, isTrue);
    expect(back.sessions.single.studentIds, {'s1'});
  });

  test('rejects files that are not, or no longer, readable backups', () {
    Matcher fails(String message) => throwsA(
      isA<FormatException>().having((e) => e.message, 'message', message),
    );
    expect(
      () => Backup.decode('date,time\n'),
      fails("This file isn't an Insight backup."),
    );
    final newer = jsonDecode(backup.encode()) as Map<String, dynamic>
      ..['version'] = 99;
    expect(
      () => Backup.decode(jsonEncode(newer)),
      fails('This backup was made by a newer version of Insight.'),
    );
    final damaged = jsonDecode(backup.encode()) as Map<String, dynamic>
      ..['students'] = [
        {'id': 's1'},
      ];
    expect(
      () => Backup.decode(jsonEncode(damaged)),
      fails('This backup is damaged.'),
    );
  });

  test('restoring replaces everything on the device', () async {
    SharedPreferences.setMockInitialValues({});
    final data = await TestData.open();
    addTearDown(data.close);
    final sessions = FixedSessions(data.sessions);

    await Backup.decode(backup.encode()).restoreInto(
      students: data.students,
      attendance: data.attendance,
      sessions: sessions,
    );

    expect(data.students.keys, ['s1']);
    expect(data.attendance.length, 2);
    expect(sessions.state.single.id, 'a');
  });
}
