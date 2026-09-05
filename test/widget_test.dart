import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insight/main.dart';
import 'package:insight/screens/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('onboarding screen navigates to privacy policy without resetting', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    await tester.pump(const Duration(milliseconds: 800));

    // Verify initial onboarding screen is displayed
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text('Fast attendance'), findsOneWidget);

    // Tap 'Skip' to jump to final step
    await tester.tap(find.text('Skip'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Ready to start'), findsOneWidget);

    // Tap 'Read policy'
    final readPolicyBtn = find.text('Read policy');
    expect(readPolicyBtn, findsOneWidget);
    await tester.tap(readPolicyBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Verify Privacy Policy screen is shown
    expect(find.text('Privacy & Security First'), findsOneWidget);

    // Tap 'Accept & Return'
    await tester.tap(find.text('Accept & Return'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Should return to page 3 of OnboardingScreen
    expect(find.text('Ready to start'), findsOneWidget);
  });
}
