import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insight/main.dart';
import 'package:insight/providers/hive_provider.dart';
import 'package:insight/providers/sessions_provider.dart';
import 'package:insight/screens/student_detail.dart';
import 'package:insight/ui/insight_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/test_app.dart';

/// The whole app past onboarding, at [size], on the real router and shell.
Future<void> pumpApp(
  WidgetTester tester,
  TestData data,
  Size size, {
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues({'onboarding_done': true, ...prefs});
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        studentsBoxProvider.overrideWith((ref) async => data.students),
        attendanceBoxProvider.overrideWith((ref) async => data.attendance),
        sessionsProvider.overrideWith((ref) => FixedSessions(data.sessions)),
      ],
      child: const InsightApp(),
    ),
  );
  await settle(tester);
}

/// Real-clock waits for the boxes, then time for transitions. The app has
/// periodic clocks, so the tree never fully settles.
Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  late TestData data;
  const phone = Size(390, 844);

  setUpAll(() async => data = await TestData.open());
  tearDownAll(() => data.close());

  testWidgets('phone shows the glass tab bar and switches sections', (
    tester,
  ) async {
    await pumpApp(tester, data, phone);
    expect(find.byType(GlassTabBar), findsOneWidget);
    for (final label in [
      'Today',
      'Attendance',
      'Students',
      'Sessions',
      'Reports',
    ]) {
      expect(find.byKey(ValueKey('tab-$label')), findsOneWidget);
    }
    expect(
      find.byKey(const ValueKey('tab-Settings')),
      findsNothing,
      reason: 'Settings is reached from Today, not the bar',
    );

    await tester.tap(find.byKey(const ValueKey('tab-Students')));
    await settle(tester);
    expect(find.textContaining('12 enrolled'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a tab keeps its stack; re-tapping it pops to the root', (
    tester,
  ) async {
    await pumpApp(tester, data, phone);
    await tester.tap(find.byKey(const ValueKey('tab-Students')));
    await settle(tester);
    await tester.tap(find.text('Student Number 0 Longname'));
    await settle(tester);
    expect(find.byType(StudentDetailScreen), findsOneWidget);

    // Away and back: still on the student.
    await tester.tap(find.byKey(const ValueKey('tab-Reports')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('tab-Students')));
    await settle(tester);
    expect(find.byType(StudentDetailScreen), findsOneWidget);

    // The current tab again: back to the roster.
    await tester.tap(find.byKey(const ValueKey('tab-Students')));
    await settle(tester);
    expect(find.byType(StudentDetailScreen), findsNothing);
    expect(find.textContaining('12 enrolled'), findsOneWidget);
  });

  testWidgets('sections get the bar height as bottom padding', (tester) async {
    await pumpApp(tester, data, phone);
    final context = tester.element(find.text('Today').first);
    expect(
      MediaQuery.paddingOf(context).bottom,
      greaterThanOrEqualTo(GlassTabBar.height + GlassTabBar.bottomGap),
    );
  });

  testWidgets('wide windows use the sidebar instead of the bar', (
    tester,
  ) async {
    await pumpApp(tester, data, const Size(1280, 860));
    expect(find.byType(GlassTabBar), findsNothing);
    expect(find.text('Start Kiosk'), findsOneWidget);
  });

  testWidgets('the bar stays on pushed screens and hides under sheets', (
    tester,
  ) async {
    // Visible and tappable, as opposed to built but covered by a sheet.
    final bar = find.byType(GlassTabBar).hitTestable();
    await pumpApp(tester, data, phone);

    // Settings, from Today's gear: the bar stays, with Today highlighted.
    await tester.tap(find.bySemanticsLabel('Settings'));
    await settle(tester);
    expect(find.text('Set Admin PIN'), findsOneWidget);
    expect(bar, findsOneWidget);

    // A page pushed inside Settings keeps the bar, as on iOS.
    await tester.scrollUntilVisible(
      find.text('About Insight'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    // Past the floating bar: the row can sit under it when first visible.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -200));
    await settle(tester);
    await tester.tap(find.text('About Insight'));
    await settle(tester);
    expect(find.text('Offline biometric attendance'), findsOneWidget);
    expect(bar, findsOneWidget);

    // A student's detail, pushed inside Students, keeps it too.
    await tester.tap(find.byKey(const ValueKey('tab-Students')));
    await settle(tester);
    await tester.tap(find.text('Student Number 0 Longname'));
    await settle(tester);
    expect(find.byType(StudentDetailScreen), findsOneWidget);
    expect(bar, findsOneWidget);

    // A sheet is a separate task: it covers the bar.
    await tester.tap(find.byKey(const ValueKey('tab-Sessions')));
    await settle(tester);
    await tester.tap(find.bySemanticsLabel('Add Session'));
    await settle(tester);
    expect(find.text('New Session'), findsOneWidget);
    expect(bar, findsNothing);
  });
}
