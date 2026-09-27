import '../models/attendance.dart';
import '../models/session_entry.dart';
import '../models/student.dart';
import 'session_clock.dart';

enum ReportRange { week, month, term, all }

extension ReportRangeInfo on ReportRange {
  /// Days covered, or null for all time.
  int? get days => switch (this) {
    ReportRange.week => 7,
    ReportRange.month => 30,
    ReportRange.term => 90,
    ReportRange.all => null,
  };

  String get label => switch (this) {
    ReportRange.week => '7 Days',
    ReportRange.month => '30 Days',
    ReportRange.term => '90 Days',
    ReportRange.all => 'All',
  };

  /// "the previous 7 days", for comparisons.
  String get previousLabel => 'previous ${days ?? 0} days';
}

/// One column of the check-ins chart: a day, or a week for long ranges.
class ReportBucket {
  const ReportBucket({
    required this.start,
    required this.label,
    required this.onTime,
    required this.late,
    required this.averageScanMs,
  });

  final DateTime start;
  final String label;
  final int onTime;
  final int late;
  final int? averageScanMs;

  int get total => onTime + late;
}

class SessionReport {
  const SessionReport({
    required this.title,
    required this.meetings,
    required this.averagePresent,
    required this.rate,
    required this.lateShare,
  });

  final String title;

  /// Days in range with at least one check-in for the session.
  final int meetings;
  final double averagePresent;

  /// Average present over expected (or enrolled), 0–1.
  final double rate;

  /// Late check-ins over all check-ins, 0–1.
  final double lateShare;
}

class StudentPresence {
  const StudentPresence({
    required this.student,
    required this.daysPresent,
    required this.classDays,
    required this.lateCount,
  });

  final Student student;
  final int daysPresent;
  final int classDays;
  final int lateCount;

  double get rate => classDays == 0 ? 0 : daysPresent / classDays;
}

/// Arrival-time bins relative to the session start, in minutes.
const arrivalBins = <(String, int, int)>[
  ('Early', -1440, 0),
  ('0–5', 0, 5),
  ('5–10', 5, 10),
  ('10–15', 10, 15),
  ('15–30', 15, 30),
  ('30+', 30, 1440),
];

/// Everything the Reports screen shows for one range and session filter.
class ReportData {
  ReportData._({
    required this.range,
    required this.buckets,
    required this.weekly,
    required this.checkIns,
    required this.previousCheckIns,
    required this.studentsSeen,
    required this.attendanceRate,
    required this.previousAttendanceRate,
    required this.lateShare,
    required this.previousLateShare,
    required this.averageScanMs,
    required this.arrivals,
    required this.sessions,
    required this.followUp,
    required this.classDays,
  });

  final ReportRange range;
  final List<ReportBucket> buckets;

  /// Whether [buckets] are weeks rather than days.
  final bool weekly;
  final int checkIns;
  final int? previousCheckIns;
  final int studentsSeen;

  /// Average share of the class present on class days, 0–1; null without
  /// class days.
  final double? attendanceRate;
  final double? previousAttendanceRate;
  final double? lateShare;
  final double? previousLateShare;
  final int? averageScanMs;

  /// Check-ins per [arrivalBins] entry.
  final List<int> arrivals;
  final List<SessionReport> sessions;

  /// Students with the lowest presence, lowest first.
  final List<StudentPresence> followUp;
  final int classDays;

  static ReportData compute({
    required List<Student> students,
    required Iterable<Attendance> attendance,
    required List<SessionEntry> sessions,
    required ReportRange range,
    required DateTime now,
    String? session,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final byTitle = {for (final s in sessions) s.title: s};
    final names = {for (final s in students) s.id};
    DateTime day(DateTime t) => DateTime(t.year, t.month, t.day);

    final scoped = attendance
        .where((a) => session == null || a.sessionTitle == session)
        .toList();

    DateTime start;
    if (range.days != null) {
      start = today.subtract(Duration(days: range.days! - 1));
    } else if (scoped.isEmpty) {
      start = today;
    } else {
      start = day(
        scoped.map((a) => a.timestamp).reduce((a, b) => a.isBefore(b) ? a : b),
      );
    }
    final end = today.add(const Duration(days: 1));
    bool inRange(DateTime t, DateTime from, DateTime to) =>
        !t.isBefore(from) && t.isBefore(to);

    final current = scoped
        .where((a) => inRange(a.timestamp, start, end))
        .toList();
    bool isLate(Attendance a) {
      final s = byTitle[a.sessionTitle];
      return s != null && isLateFor(s, a.timestamp);
    }

    // Columns: days up to a month, weeks beyond.
    final spanDays = end.difference(start).inDays;
    final weekly = spanDays > 31;
    final step = weekly ? 7 : 1;
    final buckets = <ReportBucket>[];
    for (var from = start; from.isBefore(end);) {
      final to = from.add(Duration(days: step));
      final inBucket = current.where((a) => inRange(a.timestamp, from, to));
      final late = inBucket.where(isLate).length;
      final scans = inBucket.map((a) => a.latencyMs).whereType<int>().toList();
      buckets.add(
        ReportBucket(
          start: from,
          label: weekly ? _shortDate(from) : _dayLabel(from, spanDays),
          onTime: inBucket.length - late,
          late: late,
          averageScanMs: scans.isEmpty
              ? null
              : scans.reduce((a, b) => a + b) ~/ scans.length,
        ),
      );
      from = to;
    }

    // Presence: on each class day, the share of the class checked in.
    final expected = session != null && (byTitle[session]?.expected ?? 0) > 0
        ? byTitle[session]!.expected
        : students.length;
    double? rateFor(List<Attendance> records) {
      if (expected == 0) return null;
      final perDay = <DateTime, Set<String>>{};
      for (final a in records) {
        (perDay[day(a.timestamp)] ??= {}).add(a.studentId);
      }
      if (perDay.isEmpty) return null;
      final shares = perDay.values.map(
        (ids) => (ids.length / expected).clamp(0.0, 1.0),
      );
      return shares.reduce((a, b) => a + b) / perDay.length;
    }

    double? lateShareFor(List<Attendance> records) {
      final timed = records.where((a) => byTitle.containsKey(a.sessionTitle));
      if (timed.isEmpty) return null;
      return timed.where(isLate).length / timed.length;
    }

    List<Attendance>? previous;
    if (range.days != null) {
      final prevStart = start.subtract(Duration(days: range.days!));
      previous = scoped
          .where((a) => inRange(a.timestamp, prevStart, start))
          .toList();
    }

    final arrivals = List<int>.filled(arrivalBins.length, 0);
    for (final a in current) {
      final s = byTitle[a.sessionTitle];
      if (s == null) continue;
      final offset = minuteOfDay(a.timestamp) - s.startMinuteOfDay;
      for (var i = 0; i < arrivalBins.length; i++) {
        if (offset >= arrivalBins[i].$2 && offset < arrivalBins[i].$3) {
          arrivals[i]++;
          break;
        }
      }
    }

    final sessionReports = <SessionReport>[];
    final titles = current
        .map((a) => a.sessionTitle)
        .whereType<String>()
        .toSet();
    for (final title in titles) {
      final records = current.where((a) => a.sessionTitle == title).toList();
      final perDay = <DateTime, Set<String>>{};
      for (final a in records) {
        (perDay[day(a.timestamp)] ??= {}).add(a.studentId);
      }
      final avg =
          perDay.values.map((s) => s.length).reduce((a, b) => a + b) /
          perDay.length;
      final exp = (byTitle[title]?.expected ?? 0) > 0
          ? byTitle[title]!.expected
          : students.length;
      sessionReports.add(
        SessionReport(
          title: title,
          meetings: perDay.length,
          averagePresent: avg,
          rate: exp == 0 ? 0 : (avg / exp).clamp(0.0, 1.0),
          lateShare: records.where(isLate).length / records.length,
        ),
      );
    }
    sessionReports.sort((a, b) => a.rate.compareTo(b.rate));

    final classDaySet = current.map((a) => day(a.timestamp)).toSet();
    final presence =
        [
          for (final s in students)
            StudentPresence(
              student: s,
              daysPresent: current
                  .where((a) => a.studentId == s.id)
                  .map((a) => day(a.timestamp))
                  .toSet()
                  .length,
              classDays: classDaySet.length,
              lateCount: current
                  .where((a) => a.studentId == s.id && isLate(a))
                  .length,
            ),
        ]..sort((a, b) {
          final byRate = a.rate.compareTo(b.rate);
          return byRate != 0
              ? byRate
              : a.student.name.toLowerCase().compareTo(
                  b.student.name.toLowerCase(),
                );
        });

    final scans = current.map((a) => a.latencyMs).whereType<int>().toList();

    return ReportData._(
      range: range,
      buckets: buckets,
      weekly: weekly,
      checkIns: current.length,
      previousCheckIns: previous?.length,
      studentsSeen: current
          .map((a) => a.studentId)
          .where(names.contains)
          .toSet()
          .length,
      attendanceRate: rateFor(current),
      previousAttendanceRate: previous == null ? null : rateFor(previous),
      lateShare: lateShareFor(current),
      previousLateShare: previous == null ? null : lateShareFor(previous),
      averageScanMs: scans.isEmpty
          ? null
          : scans.reduce((a, b) => a + b) ~/ scans.length,
      arrivals: arrivals,
      sessions: sessionReports,
      // Only meaningful once there are a couple of class days to compare.
      followUp: classDaySet.length < 2
          ? const []
          : presence.where((p) => p.rate < 1).take(5).toList(),
      classDays: classDaySet.length,
    );
  }

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static String _shortDate(DateTime d) => '${_months[d.month - 1]} ${d.day}';

  /// Weekday initials for a week, day numbers for longer spans.
  static String _dayLabel(DateTime d, int spanDays) {
    if (spanDays <= 7) {
      const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return names[d.weekday - 1];
    }
    return _shortDate(d);
  }
}
