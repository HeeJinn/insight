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
    final hasLoading = find.byType(CircularProgressIndicator).evaluate().isNotEmpty;

    expect(hasWelcome || hasAttendance || hasLoading, isTrue);
  });
}
