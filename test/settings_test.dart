import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insight/models/attendance.dart';
import 'package:insight/providers/admin_lock_provider.dart';
import 'package:insight/providers/settings_provider.dart';
import 'package:insight/screens/settings_screen.dart';
import 'package:insight/services/data_maintenance.dart';
import 'package:hive_ce/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/test_app.dart';

void main() {
  late TestData data;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    data = await TestData.open();
  });
  tearDownAll(() => data.close());

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(SettingsScreen)));

  for (final (name, size) in testSizes) {
    testWidgets('Settings renders without overflow on a $name', (tester) async {
      await pumpScreen(
        tester,
        data: data,
        size: size,
        home: const SettingsScreen(),
      );
      expectNoOverflow(tester);
      expect(find.text('Set Admin PIN'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('About Insight'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expectNoOverflow(tester);
    });
  }

  testWidgets('sets, then changes, the admin PIN', (tester) async {
    await pumpScreen(
      tester,
      data: data,
      size: const Size(390, 844),
      home: const SettingsScreen(),
    );
    await tester.tap(find.text('Set Admin PIN'));
    await tester.pumpAndSettle();
    final fields = find.byType(CupertinoTextField);
    expect(fields, findsNWidgets(2), reason: 'no current PIN to check yet');
    await tester.enterText(fields.at(0), '2468');
    await tester.enterText(fields.at(1), '2468');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(containerOf(tester).read(adminPinProvider), '2468');

    await tester.tap(find.text('Change Admin PIN'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(CupertinoTextField).at(0), '0000');
    await tester.enterText(find.byType(CupertinoTextField).at(1), '1357');
    await tester.enterText(find.byType(CupertinoTextField).at(2), '1357');
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('The current PIN is incorrect.'), findsOneWidget);

    await tester.enterText(find.byType(CupertinoTextField).at(0), '2468');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(containerOf(tester).read(adminPinProvider), '1357');
  });

  testWidgets('theme choice and late default are saved', (tester) async {
    await pumpScreen(
      tester,
      data: data,
      size: const Size(1280, 860),
      home: const SettingsScreen(),
    );
    await tester.tap(find.text('Dark'));
    await tester.pump();
    expect(
      containerOf(tester).read(themePreferenceProvider),
      AppThemePreference.dark,
    );

    await tester.tap(find.text('Default Late Cutoff'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('5 minutes after start'));
    await tester.pumpAndSettle();
    expect(containerOf(tester).read(defaultLateAfterProvider), 5);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('default_late_after_minutes'), 5);
    expect(prefs.getString('theme_preference'), 'dark');
  });

  testWidgets('Delete Check-ins offers both scopes and can be cancelled', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      data: data,
      size: const Size(1280, 860),
      home: const SettingsScreen(),
    );
    await tester.tap(find.text('Delete Check-ins…'));
    await tester.pumpAndSettle();
    expect(find.text('Older Than 90 Days'), findsOneWidget);
    expect(find.text('All Check-ins'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Older Than 90 Days'), findsNothing);
  });

  // Plain async: Hive writes real files, which a widget test's fake clock
  // never lets finish.
  test('deleteCheckIns removes only records past the cutoff', () async {
    final box = await Hive.openBox<Attendance>('maintenance_test');
    final now = DateTime(2026, 9, 27);
    await box.addAll([
      Attendance(studentId: 'a', timestamp: DateTime(2026, 5, 1)),
      Attendance(studentId: 'b', timestamp: DateTime(2026, 9, 1)),
      Attendance(studentId: 'c', timestamp: DateTime(2026, 9, 26)),
    ]);
    expect(
      await deleteCheckIns(box, olderThan: const Duration(days: 90), now: now),
      1,
    );
    expect(box.values.map((a) => a.studentId), ['b', 'c']);
    expect(await deleteCheckIns(box), 2);
    expect(box.isEmpty, isTrue);
    await box.deleteFromDisk();
  });

  testWidgets('recognition page resets to balanced', (tester) async {
    await pumpScreen(
      tester,
      data: data,
      size: const Size(390, 844),
      home: const RecognitionSettingsPage(),
    );
    expectNoOverflow(tester);
    expect(find.text('Balanced'), findsOneWidget);
  });

  testWidgets('about page fits and counts local data', (tester) async {
    await pumpScreen(
      tester,
      data: data,
      size: const Size(320, 568),
      home: const AboutPage(),
    );
    expectNoOverflow(tester);
    expect(find.text('MobileFaceNet'), findsOneWidget);
  });
}
