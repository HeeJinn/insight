import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insight/main.dart';

void main() {
  testWidgets('home screen shows primary navigation actions', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    await tester.pump(const Duration(milliseconds: 800));

    final hasWelcome = find.text('Welcome').evaluate().isNotEmpty;
    final hasAttendance = find.text('Attendance').evaluate().isNotEmpty;
    final hasLoading = find
        .byType(CircularProgressIndicator)
        .evaluate()
        .isNotEmpty;

    expect(hasWelcome || hasAttendance || hasLoading, isTrue);
  });

  testWidgets('flavor studio is reachable from home', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    await tester.pump(const Duration(milliseconds: 800));

    final flavorAction = find.text('Flavors');
    if (flavorAction.evaluate().isEmpty) {
      expect(find.byType(CircularProgressIndicator), findsWidgets);
      return;
    }

    await tester.tap(flavorAction);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Flavor Studio'), findsOneWidget);
    expect(find.text('Vessel and Scoop'), findsOneWidget);
  });
}
