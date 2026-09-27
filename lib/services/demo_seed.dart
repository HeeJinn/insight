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
/// faces. The sample students have no face data and can't be recognized.
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
      await students.put(id, Student(id: id, name: names[i], embeddings: []));
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
  }
});
