import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:insight/models/attendance.dart';
import 'package:insight/models/session_entry.dart';
import 'package:insight/models/student.dart';
import 'package:insight/providers/hive_provider.dart';
import 'package:insight/providers/sessions_provider.dart';
import 'package:insight/services/session_clock.dart';
import 'package:insight/ui/insight_ui.dart';

/// Real Hive boxes in a temp directory, seeded with a running session,
/// twelve students (one enrolled with an outdated face model) and seven
/// of them checked in.
class TestData {
  TestData._(this._dir, this.students, this.attendance, this.sessions);

  final Directory _dir;
  final Box<Student> students;
  final Box<Attendance> attendance;
  final List<SessionEntry> sessions;

  static Future<TestData> open() async {
    final dir = await Directory.systemTemp.createTemp('insight_test');
    Hive.init(dir.path);
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(StudentAdapter());
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(AttendanceAdapter());
    }
    final students = await Hive.openBox<Student>('students');
    final attendance = await Hive.openBox<Attendance>('attendance');

    final now = DateTime.now();
    final minute = minuteOfDay(now);
    final running = SessionEntry(
      id: 'now',
      title: 'CS 101 · Introduction to Programming',
      room: 'Room 204',
      startMinuteOfDay: (minute - 20).clamp(0, 1439),
      endMinuteOfDay: (minute + 60).clamp(0, 1439),
      expected: 12,
    );
    // A current-model embedding is 192 values; the last student gets an
    // old-length one so they show as needing re-enrollment.
    final current = [List<double>.filled(192, 0.1)];
    final outdated = [List<double>.filled(128, 0.1)];
    for (var i = 0; i < 12; i++) {
      final id = 's${i.toString().padLeft(2, '0')}';
      await students.put(
        id,
        Student(
          id: id,
          name: 'Student Number $i Longname',
          embeddings: i == 11 ? outdated : current,
        ),
      );
      if (i < 7) {
        await attendance.add(
          Attendance(
            studentId: id,
            timestamp: now.subtract(Duration(minutes: 20 - i * 2)),
            sessionTitle: running.title,
            latencyMs: 300 + i,
          ),
        );
      }
    }
    return TestData._(dir, students, attendance, [running]);
  }

  Future<void> close() async {
    await Hive.close();
    await _dir.delete(recursive: true);
  }
}

class _FixedSessions extends SessionsController {
  _FixedSessions(List<SessionEntry> sessions) {
    state = sessions;
  }

  @override
  Future<void> load() async {}
}

/// Pumps [home] at [size] with providers backed by [data], then lets the
/// box futures resolve and animations settle.
Future<void> pumpScreen(
  WidgetTester tester, {
  required TestData data,
  required Size size,
  required Widget home,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        studentsBoxProvider.overrideWith((ref) async => data.students),
        attendanceBoxProvider.overrideWith((ref) async => data.attendance),
        sessionsProvider.overrideWith((ref) => _FixedSessions(data.sessions)),
      ],
      child: CupertinoApp(theme: insightCupertinoTheme(), home: home),
    ),
  );
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

/// Fails on a layout error, naming the widget path of any overflowing
/// flex so the offending row is easy to find.
void expectNoOverflow(WidgetTester tester) {
  final error = tester.takeException();
  if (error == null) return;
  final culprits = [
    for (final r in tester.allRenderObjects)
      if (r.toStringShallow().contains('OVERFLOWING')) '${r.debugCreator}',
  ];
  fail('$error\n${culprits.join('\n')}');
}

const testSizes = [
  ('small phone', Size(320, 568)),
  ('phone', Size(390, 844)),
  ('desktop', Size(1280, 860)),
];
