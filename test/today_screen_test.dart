import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insight/screens/today_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/test_app.dart';

void main() {
  late TestData data;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    data = await TestData.open();
  });
  tearDownAll(() => data.close());

  for (final (name, size) in testSizes) {
    testWidgets('renders without overflow on a $name', (tester) async {
      await pumpScreen(
        tester,
        data: data,
        size: size,
        home: const TodayScreen(),
      );
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
