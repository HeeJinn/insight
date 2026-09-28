import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/attendance.dart';
import '../models/session_entry.dart';
import '../models/student.dart';
import '../providers/hive_provider.dart';
import '../providers/sessions_provider.dart';
import 'session_clock.dart';

/// Debug builds started with `--dart-define=INSIGHT_DEMO=true` fill empty
/// local storage with sample students, a schedule around the current time
/// and today's check-ins, so screens can be reviewed without enrolling real
/// faces. Their placeholder face profiles can never be recognized.
const bool demoSeedEnabled = kDebugMode && bool.fromEnvironment('INSIGHT_DEMO');

final demoSeedProvider = FutureProvider<void>((ref) async {
  if (!demoSeedEnabled) return;

  final students = await ref.watch(studentsBoxProvider.future);
  final attendance = await ref.watch(attendanceBoxProvider.future);
  final sessions = ref.read(sessionsProvider.notifier);
  await sessions.load();

  final now = DateTime.now();
  final minute = minuteOfDay(now);

  SessionEntry? running;
  if (ref.read(sessionsProvider).isEmpty) {
    running = SessionEntry(
      id: 'demo-now',
      title: 'CS 101 · Programming',
      room: 'Room 204',
      startMinuteOfDay: (minute - 25).clamp(0, 1439),
      endMinuteOfDay: (minute + 65).clamp(0, 1439),
      expected: 12,
    );
    await sessions.addSession(
      SessionEntry(
        id: 'demo-earlier',
        title: 'IT 210 · Networks',
        room: 'Lab 3',
        startMinuteOfDay: (minute - 200).clamp(0, 1439),
        endMinuteOfDay: (minute - 110).clamp(0, 1439),
        expected: 10,
      ),
    );
    await sessions.addSession(running);
    await sessions.addSession(
      SessionEntry(
        id: 'demo-later',
        title: 'CS 230 · Data Structures',
        room: 'Room 118',
        startMinuteOfDay: (minute + 90).clamp(0, 1439),
        endMinuteOfDay: (minute + 180).clamp(0, 1439),
        expected: 12,
      ),
    );
  } else {
    // Reuse whatever session is running, so check-ins attach to it.
    running = activeSessionAt(ref.read(sessionsProvider), now);
  }

  if (students.isEmpty) {
    const names = [
      'Maria Santos',
      'John Dela Cruz',
      'Ana Reyes',
      'Miguel Bautista',
      'Sofia Garcia',
      'Paolo Mendoza',
      'Isabel Cruz',
      'Rafael Torres',
      'Camille Navarro',
      'Enzo Villanueva',
      'Bea Aquino',
      'Luis Ramos',
    ];
    for (var i = 0; i < names.length; i++) {
      final id = '2021-${(i + 1).toString().padLeft(4, '0')}';
      // Identical placeholder profiles: they read as enrolled, but the
      // recognizer rejects ties, so they can never match a real face. The
      // last one uses an outdated length to show the re-enroll state.
      final placeholder = List<double>.filled(
        i == names.length - 1 ? 128 : 192,
        0,
      );
      await students.put(
        id,
        Student(id: id, name: names[i], embeddings: [placeholder]),
      );
    }

    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(Duration(minutes: running?.startMinuteOfDay ?? minute - 25));
    // Seven of twelve in, two of them after the grace period.
    const offsets = [2, 4, 5, 9, 12, 18, 22];
    for (var i = 0; i < offsets.length; i++) {
      await attendance.add(
        Attendance(
          studentId: '2021-${(i + 1).toString().padLeft(4, '0')}',
          timestamp: start.add(Duration(minutes: offsets[i])),
          sessionTitle: running?.title,
          room: running?.room,
          latencyMs: 280 + i * 37,
        ),
      );
    }

    // Three weeks of weekday history for the trend charts: most students
    // most days, a few habitually late or absent. Seeded, so it is the
    // same every run.
    final history = running ?? ref.read(sessionsProvider).firstOrNull;
    if (history != null) {
      final random = Random(42);
      final today = DateTime(now.year, now.month, now.day);
      for (var back = 1; back <= 21; back++) {
        final day = today.subtract(Duration(days: back));
        if (day.weekday > 5) continue;
        for (var i = 0; i < names.length; i++) {
          // Later students attend less often, to give Follow-up a shape.
          if (random.nextDouble() > 0.95 - i * 0.04) continue;
          final lateness = i % 4 == 3
              ? 12 + random.nextInt(20)
              : random.nextInt(14) - 4;
          await attendance.add(
            Attendance(
              studentId: '2021-${(i + 1).toString().padLeft(4, '0')}',
              timestamp: day.add(
                Duration(minutes: history.startMinuteOfDay + lateness),
              ),
              sessionTitle: history.title,
              room: history.room,
              latencyMs: 260 + random.nextInt(220) - back * 3,
            ),
          );
        }
      }
    }
  }
});
