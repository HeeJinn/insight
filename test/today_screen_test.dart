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
import 'package:insight/screens/today_screen.dart';
import 'package:insight/services/session_clock.dart';
import 'package:insight/ui/insight_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FixedSessions extends SessionsController {
  _FixedSessions(List<SessionEntry> sessions) {
    state = sessions;
  }

  @override
  Future<void> load() async {}
}

void main() {
  late Directory dir;
  late Box<Student> students;
  late Box<Attendance> attendance;
  late List<SessionEntry> sessions;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    dir = await Directory.systemTemp.createTemp('insight_today_test');
    Hive.init(dir.path);
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(StudentAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(AttendanceAdapter());
    students = await Hive.openBox<Student>('students');
    attendance = await Hive.openBox<Attendance>('attendance');

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
    sessions = [running];
    for (var i = 0; i < 12; i++) {
      final id = 's$i';
      await students.put(
        id,
        Student(id: id, name: 'Student Number $i Longname', embeddings: []),
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
  });

  tearDownAll(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  Future<void> pumpAt(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          studentsBoxProvider.overrideWith((ref) async => students),
          attendanceBoxProvider.overrideWith((ref) async => attendance),
          sessionsProvider.overrideWith((ref) => _FixedSessions(sessions)),
        ],
        child: CupertinoApp(
          theme: insightCupertinoTheme(),
          home: const TodayScreen(),
        ),
      ),
    );
    // Let the box futures resolve, then settle animations.
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  for (final (name, size) in [
    ('small phone', const Size(320, 568)),
    ('phone', const Size(390, 844)),
    ('desktop', const Size(1280, 860)),
  ]) {
    testWidgets('renders without overflow on a $name', (tester) async {
      await pumpAt(tester, size);
      expectNoOverflow(tester);
      expect(find.text('Today'), findsWidgets);
      expect(find.text('In Session'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Not Checked In'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expectNoOverflow(tester);
    });
  }
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
