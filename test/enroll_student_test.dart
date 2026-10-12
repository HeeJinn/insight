import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insight/models/student.dart';
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

    // Letters are dropped and dashes added; a short ID can't continue.
    await tester.enterText(fields.at(1), 's03');
    await tester.pump();
    expect(find.text('03'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    expect(find.text('Enter the full ID, like 00-0000-00000.'), findsOneWidget);

    await tester.runAsync(
      () => data.students.put(
        '21-0123-45678',
        Student(id: '21-0123-45678', name: 'Taken', embeddings: []),
      ),
    );
    addTearDown(
      () => tester.runAsync(() => data.students.delete('21-0123-45678')),
    );
    await tester.enterText(fields.at(1), '21012345678');
    await tester.pump();
    expect(find.text('21-0123-45678'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    expect(
      find.text('A student with ID 21-0123-45678 is already enrolled.'),
      findsOneWidget,
    );
    expect(find.text('Add a Student'), findsOneWidget);

    // Editing clears the error.
    await tester.enterText(fields.at(1), '21012345679');
    await tester.pump();
    expect(find.textContaining('already enrolled'), findsNothing);
  });
}
