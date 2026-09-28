import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insight/models/attendance.dart';
import 'package:insight/models/student.dart';
import 'package:insight/screens/student_detail.dart';
import 'package:insight/screens/students_screen.dart';
import 'package:insight/services/student_stats.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/test_app.dart';

void main() {
  late TestData data;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    data = await TestData.open();
  });
  tearDownAll(() => data.close());

  group('StudentsScreen', () {
    for (final (name, size) in testSizes) {
      testWidgets('renders without overflow on a $name', (tester) async {
        await pumpScreen(
          tester,
          data: data,
          size: size,
          home: const StudentsScreen(),
        );
        expectNoOverflow(tester);
        expect(find.text('Students'), findsWidgets);
        expect(find.textContaining('12 enrolled'), findsOneWidget);
        expect(find.textContaining('1 needs re-enrollment'), findsOneWidget);
      });
    }

    testWidgets('desktop shows the first student beside the list', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        data: data,
        size: const Size(1280, 860),
        home: const StudentsScreen(),
      );
      expect(find.byType(StudentDetailView), findsOneWidget);
      expect(find.text('ID s00'), findsOneWidget);

      await tester.tap(find.text('Student Number 3 Longname'));
      await tester.pumpAndSettle();
      expect(find.text('ID s03'), findsOneWidget);
      expectNoOverflow(tester);
    });

    testWidgets('phone pushes the detail and shows its status', (tester) async {
      await pumpScreen(
        tester,
        data: data,
        size: const Size(390, 844),
        home: const StudentsScreen(),
      );
      expect(find.byType(StudentDetailView), findsNothing);

      await tester.scrollUntilVisible(
        find.text('Student Number 11 Longname'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Student Number 11 Longname'));
      await tester.pumpAndSettle();
      expect(find.byType(StudentDetailScreen), findsOneWidget);
      expect(find.text('Needs re-enrollment'), findsOneWidget);
      // Narrow screens list the stats as rows instead of cramped tiles.
      expect(find.text('Days Present'), findsOneWidget);
      expectNoOverflow(tester);
    });

    testWidgets('search filters the roster', (tester) async {
      await pumpScreen(
        tester,
        data: data,
        size: const Size(390, 844),
        home: const StudentsScreen(),
      );
      // As on iOS, the bar's search field activates on tap before it
      // takes input.
      await tester.tap(find.byType(CupertinoSearchTextField));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(CupertinoSearchTextField), 'number 7');
      await tester.pumpAndSettle();
      expect(find.text('Student Number 7 Longname'), findsOneWidget);
      expect(find.text('Student Number 1 Longname'), findsNothing);

      await tester.enterText(find.byType(CupertinoSearchTextField), 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('No Results'), findsOneWidget);
    });
  });

  group('StudentStats', () {
    final now = DateTime(2026, 9, 27, 15);
    final records = [
      Attendance(studentId: 'a', timestamp: DateTime(2026, 9, 27, 9)),
      Attendance(studentId: 'a', timestamp: DateTime(2026, 9, 27, 13)),
      Attendance(studentId: 'a', timestamp: DateTime(2026, 9, 20, 9)),
      Attendance(studentId: 'a', timestamp: DateTime(2026, 7, 1, 9)),
      Attendance(studentId: 'b', timestamp: DateTime(2026, 9, 27, 9)),
    ];

    test('counts a student\'s own records and distinct recent days', () {
      final stats = StudentStats.of('a', records, now: now);
      expect(stats.total, 4);
      expect(stats.lastSeen, DateTime(2026, 9, 27, 13));
      expect(stats.checkedInToday, isTrue);
      expect(stats.daysPresentInLast(30), 2);
    });

    test('formats last seen relative to now', () {
      expect(formatLastSeen(null, now), 'Never');
      expect(
        formatLastSeen(DateTime(2026, 9, 27, 9, 5), now),
        'Today, 9:05 AM',
      );
      expect(formatLastSeen(DateTime(2026, 9, 26, 9), now), 'Yesterday');
      expect(formatLastSeen(DateTime(2026, 9, 23, 9), now), 'Wed');
      expect(formatLastSeen(DateTime(2026, 9, 3, 9), now), 'Sep 3');
      expect(formatLastSeen(DateTime(2025, 9, 3, 9), now), 'Sep 3, 2025');
    });

    test('face profile status follows the embedding model', () {
      Student s(List<List<double>> e) =>
          Student(id: 'x', name: 'x', embeddings: e);
      expect(faceProfileStatus(s([])), FaceProfileStatus.missing);
      expect(
        faceProfileStatus(s([List.filled(192, 0.0)])),
        FaceProfileStatus.ready,
      );
      expect(
        faceProfileStatus(s([List.filled(128, 0.0)])),
        FaceProfileStatus.needsReEnrollment,
      );
    });
  });
}
