import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insight/models/attendance.dart';
import 'package:insight/models/session_entry.dart';
import 'package:insight/providers/saved_filters_provider.dart';
import 'package:insight/screens/attendance_filter_sheet.dart';
import 'package:insight/screens/attendance_screen.dart';
import 'package:insight/services/attendance_filter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/test_app.dart';

void main() {
  final now = DateTime(2026, 9, 27, 12);
  const cs101 = SessionEntry(
    id: 'a',
    title: 'CS 101',
    room: '204',
    startMinuteOfDay: 9 * 60,
    endMinuteOfDay: 11 * 60,
    expected: 0,
    lateAfterMinutes: 10,
  );
  final names = {'s1': 'Maria Santos', 's2': 'John "JD" Cruz, Jr.'};
  final sessions = {'CS 101': cs101};
  final records = [
    Attendance(
      studentId: 's1',
      timestamp: DateTime(2026, 9, 27, 9, 5),
      sessionTitle: 'CS 101',
      room: '204',
      latencyMs: 300,
    ),
    Attendance(
      studentId: 's2',
      timestamp: DateTime(2026, 9, 27, 9, 20),
      sessionTitle: 'CS 101',
      room: '204',
    ),
    Attendance(studentId: 's1', timestamp: DateTime(2026, 9, 24, 14)),
    Attendance(studentId: 'gone', timestamp: DateTime(2026, 9, 10, 9)),
  ];

  List<Attendance> run(AttendanceFilter f) =>
      f.apply(records, namesById: names, sessionsByTitle: sessions, now: now);

  group('AttendanceFilter', () {
    test('date ranges include whole days', () {
      expect(
        run(const AttendanceFilter(range: AttendanceRange.today)),
        hasLength(2),
      );
      expect(
        run(const AttendanceFilter(range: AttendanceRange.week)),
        hasLength(3),
      );
      expect(
        run(const AttendanceFilter(range: AttendanceRange.month)),
        hasLength(4),
      );
      expect(
        run(const AttendanceFilter(range: AttendanceRange.all)),
        hasLength(4),
      );
      final custom = AttendanceFilter(
        range: AttendanceRange.custom,
        customStart: DateTime(2026, 9, 10),
        customEnd: DateTime(2026, 9, 24),
      );
      expect(run(custom).map((r) => r.studentId), ['s1', 'gone']);
    });

    test('status uses each session cutoff and spots deleted students', () {
      CheckInStatus s(Attendance r) =>
          checkInStatus(r, namesById: names, sessionsByTitle: sessions);
      expect(records.map(s), [
        CheckInStatus.onTime,
        CheckInStatus.late,
        CheckInStatus.general,
        CheckInStatus.unknownStudent,
      ]);
      expect(
        run(
          const AttendanceFilter(
            range: AttendanceRange.all,
            status: CheckInStatus.late,
          ),
        ),
        hasLength(1),
      );
    });

    test('session and search narrow the list, newest first', () {
      final bySession = run(
        const AttendanceFilter(range: AttendanceRange.all, session: 'CS 101'),
      );
      expect(bySession.map((r) => r.studentId), ['s2', 's1']);
      expect(
        run(const AttendanceFilter(range: AttendanceRange.all, query: 'maria')),
        hasLength(2),
      );
      expect(
        run(const AttendanceFilter(range: AttendanceRange.all, query: 'GONE')),
        hasLength(1),
      );
    });

    test('round-trips through JSON without the search text', () {
      final f = AttendanceFilter(
        range: AttendanceRange.custom,
        customStart: DateTime(2026, 9, 1),
        customEnd: DateTime(2026, 9, 7),
        session: 'CS 101',
        status: CheckInStatus.late,
        query: 'not saved',
      );
      final back = AttendanceFilter.fromJson(f.toJson());
      expect(back.sameAs(f), isTrue);
      expect(back.query, isEmpty);
      expect(
        AttendanceFilter.fromJson({'range': 'bogus'}).range,
        AttendanceRange.week,
      );
    });
  });

  test('CSV quotes every cell and labels status', () {
    final csv = attendanceCsv(
      records.take(2).toList(),
      namesById: names,
      sessionsByTitle: sessions,
    );
    final lines = csv.trim().split('\r\n');
    expect(
      lines.first,
      'date,time,student_id,student_name,session,room,status,scan_ms',
    );
    expect(
      lines[1],
      '"2026-09-27","09:05:00","s1","Maria Santos","CS 101","204","On time","300"',
    );
    expect(lines[2], contains('"John ""JD"" Cruz, Jr."'));
    expect(lines[2], contains('"Late",""'));
  });

  test('saved filters persist, replace by name, and delete', () async {
    SharedPreferences.setMockInitialValues({});
    final a = SavedFiltersController();
    await a.save(
      'Late today',
      const AttendanceFilter(
        range: AttendanceRange.today,
        status: CheckInStatus.late,
      ),
    );
    await a.save('CS', const AttendanceFilter(session: 'CS 101'));
    await a.save('CS', const AttendanceFilter(session: 'CS 102'));
    final b = SavedFiltersController();
    await b.load();
    expect(b.state.map((s) => s.name), ['Late today', 'CS']);
    expect(b.state.last.filter.session, 'CS 102');
    await b.delete('Late today');
    expect(b.state.map((s) => s.name), ['CS']);
  });

  group('screens', () {
    late TestData data;

    setUpAll(() async {
      SharedPreferences.setMockInitialValues({});
      data = await TestData.open();
    });
    tearDownAll(() => data.close());

    for (final (name, size) in testSizes) {
      testWidgets('Attendance renders without overflow on a $name', (
        tester,
      ) async {
        await pumpScreen(
          tester,
          data: data,
          size: size,
          home: const AttendanceScreen(),
        );
        expectNoOverflow(tester);
        expect(find.textContaining('7 check-ins'), findsOneWidget);
        // The desktop table has sortable headers; phones group by day.
        if (size.width >= 1000) {
          expect(find.text('Date & Time'), findsOneWidget);
        } else {
          expect(find.text('Today'), findsWidgets);
        }
      });
    }

    for (final (name, size) in testSizes) {
      testWidgets('filter sheet fits on a $name', (tester) async {
        await pumpScreen(
          tester,
          data: data,
          size: size,
          home: const _SheetHost(),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expectNoOverflow(tester);
        expect(find.text('Date Range'), findsOneWidget);
      });
    }

    testWidgets('choosing a range and a status narrows the list', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        data: data,
        size: const Size(1280, 860),
        home: const AttendanceScreen(),
      );
      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();
      expect(find.textContaining('7 check-ins'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Filter'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Unknown Student'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Unknown Student'));
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('No Matches'), findsOneWidget);
      expect(find.text('Unknown student'), findsOneWidget, reason: 'chip');

      await tester.tap(find.text('Reset Filters'));
      await tester.pumpAndSettle();
      expect(find.textContaining('7 check-ins'), findsOneWidget);
    });

    testWidgets('sorting by student toggles direction', (tester) async {
      await pumpScreen(
        tester,
        data: data,
        size: const Size(1280, 860),
        home: const AttendanceScreen(),
      );
      double y(String text) => tester.getTopLeft(find.text(text)).dy;

      await tester.tap(find.bySemanticsLabel('Sort by Student'));
      await tester.pumpAndSettle();
      expect(
        y('Student Number 0 Longname'),
        lessThan(y('Student Number 6 Longname')),
      );

      await tester.tap(find.bySemanticsLabel('Sort by Student'));
      await tester.pumpAndSettle();
      expect(
        y('Student Number 6 Longname'),
        lessThan(y('Student Number 0 Longname')),
      );
    });

    testWidgets('saved filters apply from the bookmark menu', (tester) async {
      await pumpScreen(
        tester,
        data: data,
        size: const Size(1280, 860),
        home: const AttendanceScreen(),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AttendanceScreen)),
      );
      await container
          .read(savedFiltersProvider.notifier)
          .save(
            'Late only',
            const AttendanceFilter(status: CheckInStatus.late),
          );
      await tester.pump();

      await tester.tap(find.bySemanticsLabel('Saved Filters'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Late only'));
      await tester.pumpAndSettle();
      // The sample data has no late check-ins, so the applied filter
      // empties the list and shows its chip.
      expect(find.text('No Matches'), findsOneWidget);
      expect(find.text('Late'), findsOneWidget, reason: 'status chip');
    });
  });
}

class _SheetHost extends StatelessWidget {
  const _SheetHost();

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: Center(
        child: CupertinoButton(
          onPressed: () => showAttendanceFilterSheet(
            context,
            filter: AttendanceFilter.defaults,
            sessionTitles: const [
              'CS 101 · Introduction to Programming',
              'IT 210',
            ],
          ),
          child: const Text('Open'),
        ),
      ),
    );
  }
}
