import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insight/models/attendance.dart';
import 'package:insight/models/session_entry.dart';
import 'package:insight/models/student.dart';
import 'package:insight/screens/reports_screen.dart';
import 'package:insight/services/report_data.dart';
import 'package:insight/ui/insight_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/test_app.dart';

void main() {
  final now = DateTime(2026, 9, 27, 18);
  final students = [
    for (final (id, name) in [
      ('a', 'Ana'),
      ('b', 'Ben'),
      ('c', 'Cy'),
      ('d', 'Dee'),
    ])
      Student(id: id, name: name, embeddings: []),
  ];
  const cs = SessionEntry(
    id: 'cs',
    title: 'CS',
    room: '',
    startMinuteOfDay: 9 * 60,
    endMinuteOfDay: 10 * 60,
    expected: 4,
    lateAfterMinutes: 10,
  );
  Attendance at(
    String id,
    int day,
    int h,
    int m, {
    String? session = 'CS',
    int? ms,
  }) => Attendance(
    studentId: id,
    timestamp: DateTime(2026, 9, day, h, m),
    sessionTitle: session,
    latencyMs: ms,
  );

  // Two class days this week, one last week.
  final records = [
    at('a', 27, 8, 58, ms: 300), // early
    at('b', 27, 9, 3, ms: 500), // 0–5
    at('c', 27, 9, 12), // late (10–15)
    at('a', 25, 9, 1),
    at('b', 25, 9, 40), // 30+, late
    at('a', 18, 9, 0), // previous week
    at('b', 18, 9, 0),
    at('c', 18, 9, 0),
    at('d', 18, 9, 0),
  ];

  ReportData compute(ReportRange range, {String? session}) =>
      ReportData.compute(
        students: students,
        attendance: records,
        sessions: const [cs],
        range: range,
        now: now,
        session: session,
      );

  group('ReportData', () {
    test('headline figures and comparison with the previous period', () {
      final d = compute(ReportRange.week);
      expect(d.checkIns, 5);
      expect(d.previousCheckIns, 4);
      expect(d.studentsSeen, 3);
      expect(d.classDays, 2);
      // Sep 27: 3 of 4 present; Sep 25: 2 of 4 → average 62.5%.
      expect(d.attendanceRate, closeTo(0.625, 1e-9));
      expect(d.previousAttendanceRate, 1.0);
      expect(d.lateShare, closeTo(2 / 5, 1e-9));
      expect(d.previousLateShare, 0);
      expect(d.averageScanMs, 400);
    });

    test('one column per day for a week, weekly beyond a month', () {
      final week = compute(ReportRange.week);
      expect(week.weekly, isFalse);
      expect(week.buckets, hasLength(7));
      expect(week.buckets.last.onTime, 2);
      expect(week.buckets.last.late, 1);
      expect(week.buckets.last.label, 'Sun');

      final term = compute(ReportRange.term);
      expect(term.weekly, isTrue);
      expect(term.buckets.fold(0, (n, b) => n + b.total), records.length);
    });

    test('arrival bins are minutes from the session start', () {
      expect(compute(ReportRange.week).arrivals, [1, 2, 0, 1, 0, 1]);
    });

    test('per-session rates and who needs follow-up', () {
      final d = compute(ReportRange.week);
      expect(d.sessions.single.meetings, 2);
      expect(d.sessions.single.averagePresent, 2.5);
      expect(d.sessions.single.rate, closeTo(0.625, 1e-9));
      // Dee missed both days and Cy one; Ana and Ben came both days.
      expect(d.followUp.map((p) => p.student.name), ['Dee', 'Cy']);
      expect(d.followUp.first.daysPresent, 0);
      expect(d.followUp.last.lateCount, 1, reason: 'Cy was late once');
    });

    test('a session filter scopes everything; all time has no comparison', () {
      final none = compute(ReportRange.all, session: 'Other');
      expect(none.checkIns, 0);
      expect(none.attendanceRate, isNull);
      final all = compute(ReportRange.all);
      expect(all.previousCheckIns, isNull);
      expect(all.checkIns, records.length);
    });
  });

  group('screen', () {
    late TestData data;

    setUpAll(() async {
      SharedPreferences.setMockInitialValues({});
      data = await TestData.open();
    });
    tearDownAll(() => data.close());

    for (final (name, size) in testSizes) {
      testWidgets('Reports renders without overflow on a $name', (
        tester,
      ) async {
        await pumpScreen(
          tester,
          data: data,
          size: size,
          home: const ReportsScreen(),
        );
        expectNoOverflow(tester);
        expect(find.text('Attendance'), findsOneWidget);
        expect(find.text('Check-ins'), findsWidgets);
        for (final title in [
          'Arrival Times',
          'By Session',
          'Needs Follow-up',
          'Recognition Speed',
        ]) {
          await tester.scrollUntilVisible(
            find.text(title),
            300,
            scrollable: find.byType(Scrollable).first,
          );
          expectNoOverflow(tester);
        }
      });
    }

    testWidgets('a chart switches to its table and back', (tester) async {
      await pumpScreen(
        tester,
        data: data,
        size: const Size(1280, 860),
        home: const ReportsScreen(),
      );
      await tester.tap(find.bySemanticsLabel('Show Table').first);
      await tester.pumpAndSettle();
      expect(find.text('On time'), findsWidgets);
      expect(find.text('Total'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Show Chart'));
      await tester.pumpAndSettle();
      expect(find.text('Total'), findsNothing);
      expectNoOverflow(tester);
    });

    testWidgets('hovering a column shows its values', (tester) async {
      await pumpScreen(
        tester,
        data: data,
        size: const Size(1280, 860),
        home: const ReportsScreen(),
      );
      final chart = find.byType(ColumnChartProbe.type).first;
      final box = tester.getRect(chart);
      // The last column is today, where every sample check-in lands.
      await tester.tapAt(Offset(box.right - 20, box.center.dy));
      await tester.pumpAndSettle();
      expect(find.text('Total'), findsOneWidget);
      expect(find.text('7'), findsWidgets);
    });
  });
}

/// Finds the design system's column chart without importing its private
/// state.
class ColumnChartProbe {
  static const type = ColumnChart;
}
