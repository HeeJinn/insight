import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/test_app.dart';

void main() {
  late TestData data;
  setUpAll(() async => data = await TestData.open());
  tearDownAll(() => data.close());

  // Tests have no camera. Denying it keeps the scanner from reaching for
  // one, so the panel beside it can be checked on its own.
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter.baseflow.com/permissions/methods'),
          (call) async => call.method == 'requestPermissions' ? {1: 0} : 0,
        );
  });

  for (final (name, size) in testSizes) {
    testWidgets('every kiosk state reads cleanly on a $name', (tester) async {
      await pumpApp(tester, data, size);
      GoRouter.of(tester.element(find.byType(Navigator).first)).go('/kiosk');
      await settle(tester);

      // At rest: whether arriving now is on time, and nobody's name.
      expect(
        find.textContaining(RegExp(r'^(On time until|Check-ins now count)')),
        findsOneWidget,
      );
      expect(find.textContaining('Student Number'), findsNothing);
      expect(tester.takeException(), isNull);

      // F7–F10 fake each scan outcome in debug builds.
      for (final (key, text) in [
        (LogicalKeyboardKey.f7, RegExp(r'^(On time|Late) · ')),
        (LogicalKeyboardKey.f8, RegExp(r'^Already checked in · ')),
        (LogicalKeyboardKey.f9, RegExp(r'^Face Not Recognized$')),
        (LogicalKeyboardKey.f10, RegExp(r'^Not on the Class List$')),
      ]) {
        await tester.sendKeyEvent(key);
        await settle(tester);
        expect(find.textContaining(text), findsOneWidget, reason: '$key');
        expect(tester.takeException(), isNull);
      }
    });
  }
}
