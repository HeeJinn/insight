import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insight/models/session_entry.dart';
import 'package:insight/providers/sessions_provider.dart';
import 'package:insight/screens/session_editor.dart';
import 'package:insight/screens/sessions_screen.dart';
import 'package:insight/services/session_clock.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/test_app.dart';

void main() {
  // Sunday 27 September 2026.
  DateTime at(int day, int h, int m) => DateTime(2026, 9, day, h, m);

  const mwf = SessionEntry(
    id: 'mwf',
    title: 'CS 101',
    room: '204',
    startMinuteOfDay: 9 * 60,
    endMinuteOfDay: 10 * 60 + 30,
    expected: 0,
    weekdays: {1, 3, 5},
    lateAfterMinutes: 10,
  );

  group('SessionEntry', () {
    test('sessions saved before repeat days run every day', () {
      final legacy = SessionEntry.fromJson({
        'id': 'x',
        'title': 'Old',
        'room': '',
        'startMinuteOfDay': 480,
        'endMinuteOfDay': 540,
        'expected': 3,
      });
      expect(legacy.weekdays, SessionEntry.everyDay);
      expect(legacy.isOneOff, isFalse);
      expect(legacy.lateAfterMinutes, SessionEntry.defaultLateAfterMinutes);
    });

    test('round-trips recurring and one-off sessions through JSON', () {
      final oneOff = mwf.copyWith(date: DateTime(2026, 10, 2, 15, 30));
      for (final s in [mwf, oneOff]) {
        final back = SessionEntry.fromJson(s.toJson());
        expect(back.weekdays, s.weekdays);
        expect(back.lateAfterMinutes, 10);
        expect(back.date == null, s.date == null);
      }
      expect(
        SessionEntry.fromJson(oneOff.toJson()).date,
        DateTime(2026, 10, 2),
        reason: 'stored as a calendar day',
      );
    });

    test('occurs on its weekdays, or only on its date', () {
      expect(mwf.occursOn(at(28, 9, 0)), isTrue, reason: 'Monday');
      expect(mwf.occursOn(at(29, 9, 0)), isFalse, reason: 'Tuesday');
      final oneOff = mwf.copyWith(date: DateTime(2026, 9, 29));
      expect(oneOff.occursOn(at(29, 9, 0)), isTrue);
      expect(oneOff.occursOn(at(28, 9, 0)), isFalse);
    });
  });

  group('session_clock', () {
    final makeUp = mwf.copyWith(
      title: 'CS 101 Make-up',
      startMinuteOfDay: 9 * 60 + 30,
      date: DateTime(2026, 9, 28),
    );

    test('only sessions meeting today are active or next', () {
      expect(activeSessionAt([mwf], at(28, 9, 30))?.id, 'mwf');
      expect(activeSessionAt([mwf], at(29, 9, 30)), isNull);
      expect(nextSessionAfter([mwf], at(29, 8, 0)), isNull);
      expect(nextSessionAfter([mwf], at(28, 8, 0))?.id, 'mwf');
    });

    test('a one-off overrides the weekly session while both run', () {
      expect(
        activeSessionAt([mwf, makeUp], at(28, 9, 45))?.title,
        'CS 101 Make-up',
      );
      expect(activeSessionAt([mwf, makeUp], at(28, 9, 10))?.title, 'CS 101');
    });

    test('lateness uses each session\'s own cutoff', () {
      expect(isLateFor(mwf, at(28, 9, 10)), isFalse);
      expect(isLateFor(mwf, at(28, 9, 11)), isTrue);
    });

    test('describes repeat days and dates', () {
      expect(formatWeekdays({1, 2, 3, 4, 5}), 'Weekdays');
      expect(formatWeekdays({6, 7}), 'Weekends');
      expect(formatWeekdays(SessionEntry.everyDay), 'Every day');
      expect(formatWeekdays({5, 1, 3}), 'Mon, Wed, Fri');
      final now = at(27, 12, 0);
      expect(
        formatRecurrence(mwf.copyWith(date: DateTime(2026, 9, 27)), now),
        'Today',
      );
      expect(
        formatRecurrence(mwf.copyWith(date: DateTime(2026, 9, 28)), now),
        'Tomorrow',
      );
      expect(
        formatRecurrence(mwf.copyWith(date: DateTime(2026, 10, 2)), now),
        'Fri, Oct 2',
      );
      expect(
        formatRecurrence(mwf.copyWith(date: DateTime(2027, 1, 4)), now),
        'Mon, Jan 4, 2027',
      );
    });
  });

  group('screens', () {
    late TestData data;

    setUpAll(() async {
      SharedPreferences.setMockInitialValues({});
      data = await TestData.open();
    });
    tearDownAll(() => data.close());

    for (final (name, size) in testSizes) {
      testWidgets('Sessions renders without overflow on a $name', (
        tester,
      ) async {
        await pumpScreen(
          tester,
          data: data,
          size: size,
          home: const SessionsScreen(),
        );
        expectNoOverflow(tester);
        expect(find.text('Sessions'), findsWidgets);
        expect(find.text('Weekly Schedule'), findsOneWidget);
        expect(find.textContaining('7 checked in'), findsOneWidget);
      });
    }

    for (final (name, size) in testSizes) {
      testWidgets('editor fits on a $name', (tester) async {
        await pumpScreen(
          tester,
          data: data,
          size: size,
          home: const _EditorHost(),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expectNoOverflow(tester);
        expect(find.text('New Session'), findsOneWidget);
      });
    }

    testWidgets('editor validates, then saves a weekly session', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        data: data,
        size: const Size(390, 844),
        home: const _EditorHost(),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      CupertinoButton save() => tester.widget(
        find.ancestor(
          of: find.text('Save'),
          matching: find.byType(CupertinoButton),
        ),
      );
      expect(save().onPressed, isNull, reason: 'needs a name');

      await tester.enterText(find.byType(CupertinoTextField).first, 'Physics');
      await tester.pump();
      expect(save().onPressed, isNotNull);

      // Clearing every day blocks saving with an explanation.
      for (final day in [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
      ]) {
        await tester.tap(find.bySemanticsLabel(day));
        await tester.pump();
      }
      expect(save().onPressed, isNull);
      expect(find.text('Choose at least one day.'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Tuesday'));
      await tester.tap(find.bySemanticsLabel('Thursday'));
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(_EditorHost)),
      );
      final saved = container
          .read(sessionsProvider)
          .firstWhere((s) => s.title == 'Physics');
      expect(saved.weekdays, {2, 4});
      expect(saved.isOneOff, isFalse);
      expect(find.text('New Session'), findsNothing, reason: 'sheet closed');
    });

    testWidgets('Start Now drafts a one-time session from now', (tester) async {
      final now = DateTime.now();
      final draft = draftSessionNow(now);
      expect(draft.isOneOff, isTrue);
      expect(draft.occursOn(now), isTrue);
      expect(draft.startMinuteOfDay, minuteOfDay(now));
      expect(
        draft.endMinuteOfDay - draft.startMinuteOfDay,
        lessThanOrEqualTo(60),
      );
    });
  });
}

class _EditorHost extends StatelessWidget {
  const _EditorHost();

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: Center(
        child: CupertinoButton(
          onPressed: () => showSessionEditor(context),
          child: const Text('Open'),
        ),
      ),
    );
  }
}
