import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insight/screens/enroll_student_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/test_app.dart';

void main() {
  late TestData data;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    data = await TestData.open();
  });
  tearDownAll(() => data.close());

  CupertinoButton continueButton(WidgetTester tester) => tester.widget(
    find.ancestor(
      of: find.text('Continue'),
      matching: find.byType(CupertinoButton),
    ),
  );

  for (final (name, size) in testSizes) {
    testWidgets('details step fits on a $name', (tester) async {
      await pumpScreen(
        tester,
        data: data,
        size: size,
        home: const EnrollStudentScreen(),
      );
      expectNoOverflow(tester);
      expect(find.text('Add a Student'), findsOneWidget);
    });
  }

  testWidgets('Continue waits for both fields and rejects a taken ID', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      data: data,
      size: const Size(390, 844),
      home: const EnrollStudentScreen(),
    );
    expect(continueButton(tester).onPressed, isNull);

    final fields = find.byType(CupertinoTextField);
    await tester.enterText(fields.at(0), 'New Person');
    await tester.pump();
    expect(continueButton(tester).onPressed, isNull);

    await tester.enterText(fields.at(1), 's03');
    await tester.pump();
    expect(continueButton(tester).onPressed, isNotNull);

    await tester.tap(find.text('Continue'));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    expect(
      find.text('A student with ID s03 is already enrolled.'),
      findsOneWidget,
    );
    expect(find.text('Add a Student'), findsOneWidget);

    // Editing clears the error.
    await tester.enterText(fields.at(1), 's99');
    await tester.pump();
    expect(find.textContaining('already enrolled'), findsNothing);
  });
}
