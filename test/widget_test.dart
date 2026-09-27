import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insight/main.dart';
import 'package:insight/providers/admin_lock_provider.dart';
import 'package:insight/providers/app_state_provider.dart';
import 'package:insight/screens/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('onboarding walks through privacy and PIN setup', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ProviderScope(child: InsightApp()));
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text('Welcome to Insight'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await settle(tester);
    expect(find.text('Your Data Stays Here'), findsOneWidget);

    // Reading the policy and accepting it there also moves setup on.
    await tester.tap(find.text('Read Privacy Policy'));
    await settle(tester);
    expect(find.text('Privacy & Security First'), findsOneWidget);
    await tester.tap(find.text('Accept & Return'));
    await settle(tester);
    expect(find.text('Create an Admin PIN'), findsOneWidget);

    final fields = find.byType(CupertinoTextField);
    await tester.enterText(fields.at(0), '1234');
    await tester.enterText(fields.at(1), '9999');
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(find.text("The PINs don't match."), findsOneWidget);

    await tester.enterText(fields.at(1), '1234');
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await settle(tester);
    expect(find.text("You're All Set"), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(OnboardingScreen)),
    );
    expect(container.read(adminPinProvider), '1234');

    await tester.tap(find.text('Get Started'));
    await settle(tester);
    // Let the page transition finish; Today's clock timer means the tree
    // never fully settles.
    await tester.pump(const Duration(seconds: 1));
    expect(container.read(onboardingDoneProvider), isTrue);
    expect(container.read(adminUnlockedProvider), isTrue);
    expect(find.byType(OnboardingScreen), findsNothing);
  });

  for (final size in const [Size(320, 568), Size(1280, 860)]) {
    testWidgets('every onboarding page fits at ${size.width.toInt()}pt', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const ProviderScope(child: InsightApp()));
      await tester.pump(const Duration(milliseconds: 800));
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Continue'));
      await settle(tester);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Agree & Continue'));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Create an Admin PIN'), findsOneWidget);

      // Phones may postpone the PIN; the desktop kiosk may not.
      await tester.tap(find.text('Set Up Later'));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text("You're All Set"), findsOneWidget);
    });
  }
}