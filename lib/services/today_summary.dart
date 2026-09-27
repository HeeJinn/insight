import '../models/attendance.dart';
import '../models/session_entry.dart';
import '../models/student.dart';
import 'session_clock.dart';

/// The figures behind the admin Today screen, computed from local records.
class TodaySummary {
  TodaySummary._({
    required this.now,
    required this.active,
    required this.next,
    required this.todaysRecords,
    required this.activeRecords,
    required this.checkedInToday,
    required this.lateToday,
    required this.enrolled,
    required this.averageScanMs,
    required this.notCheckedIn,
  });

  factory TodaySummary.compute({
    required List<Student> students,
    required Iterable<Attendance> attendance,
    required List<SessionEntry> sessions,
    required DateTime now,
  }) {
    final active = activeSessionAt(sessions, now);
    final byTitle = {for (final s in sessions) s.title: s};

    final todays = attendance.where((a) => isSameDay(a.timestamp, now)).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // "Now" means the running session, or today's general check-ins when
    // there is no schedule at all.
    final nowTitle = active?.title;
    final activeRecords = sessions.isNotEmpty && active == null
        ? const <Attendance>[]
        : todays.where((a) => a.sessionTitle == nowTitle).toList();

    final late = todays.where((a) {
      final s = byTitle[a.sessionTitle];
      return s != null && isLateFor(s, a.timestamp);
    }).length;

    final latencies = todays
        .map((a) => a.latencyMs)
        .whereType<int>()
        .toList(growable: false);

    final presentIds = activeRecords.map((a) => a.studentId).toSet();
    final missing = students.where((s) => !presentIds.contains(s.id)).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return TodaySummary._(
      now: now,
      active: active,
      next: nextSessionAfter(sessions, now),
      todaysRecords: todays,
      activeRecords: activeRecords,
      checkedInToday: todays.map((a) => a.studentId).toSet().length,
      lateToday: late,
      enrolled: students.length,
      averageScanMs: latencies.isEmpty
          ? null
          : latencies.reduce((a, b) => a + b) ~/ latencies.length,
      notCheckedIn: missing,
    );
  }

  final DateTime now;
  final SessionEntry? active;
  final SessionEntry? next;

  /// Every check-in today, newest first.
  final List<Attendance> todaysRecords;

  /// Check-ins for the running session (or general ones with no schedule).
  final List<Attendance> activeRecords;

  /// Distinct students with at least one check-in today.
  final int checkedInToday;
  final int lateToday;
  final int enrolled;
  final int? averageScanMs;

  /// Enrolled students without a check-in for the running session.
  final List<Student> notCheckedIn;

  int get presentNow => activeRecords.map((a) => a.studentId).toSet().length;

  /// The session's expected headcount, or everyone enrolled when it has
  /// none set.
  int get expectedNow {
    final expected = active?.expected ?? 0;
    return expected > 0 ? expected : enrolled;
  }
}
