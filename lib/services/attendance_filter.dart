import '../models/attendance.dart';
import '../models/session_entry.dart';
import 'session_clock.dart';

enum AttendanceRange { today, week, month, all, custom }

/// How a check-in stands against its session.
enum CheckInStatus {
  onTime,
  late,

  /// Recorded with no session running.
  general,

  /// The student has since been deleted.
  unknownStudent,
}

/// Status of [record]. [sessionsByTitle] supplies each session's late
/// cutoff; a check-in whose session no longer exists counts as on time.
CheckInStatus checkInStatus(
  Attendance record, {
  required Map<String, String> namesById,
  required Map<String, SessionEntry> sessionsByTitle,
}) {
  if (!namesById.containsKey(record.studentId)) {
    return CheckInStatus.unknownStudent;
  }
  final title = record.sessionTitle;
  if (title == null || title.trim().isEmpty) return CheckInStatus.general;
  final session = sessionsByTitle[title];
  if (session != null && isLateFor(session, record.timestamp)) {
    return CheckInStatus.late;
  }
  return CheckInStatus.onTime;
}

/// Which check-ins the Attendance screen shows.
class AttendanceFilter {
  const AttendanceFilter({
    this.range = AttendanceRange.week,
    this.customStart,
    this.customEnd,
    this.session,
    this.status,
    this.query = '',
  });

  final AttendanceRange range;

  /// Inclusive calendar days for [AttendanceRange.custom].
  final DateTime? customStart;
  final DateTime? customEnd;

  /// Only this session's check-ins; null for all.
  final String? session;

  /// Only check-ins with this status; null for any.
  final CheckInStatus? status;

  /// Matches student name or ID. Not saved with a filter.
  final String query;

  static const AttendanceFilter defaults = AttendanceFilter();

  /// True when nothing but the date range narrows the list.
  bool get hasRefinements => session != null || status != null;

  AttendanceFilter copyWith({
    AttendanceRange? range,
    DateTime? customStart,
    DateTime? customEnd,
    String? session,
    bool clearSession = false,
    CheckInStatus? status,
    bool clearStatus = false,
    String? query,
  }) {
    return AttendanceFilter(
      range: range ?? this.range,
      customStart: customStart ?? this.customStart,
      customEnd: customEnd ?? this.customEnd,
      session: clearSession ? null : (session ?? this.session),
      status: clearStatus ? null : (status ?? this.status),
      query: query ?? this.query,
    );
  }

  /// The first day included, or null for all time.
  DateTime? startDay(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return switch (range) {
      AttendanceRange.today => today,
      AttendanceRange.week => today.subtract(const Duration(days: 6)),
      AttendanceRange.month => today.subtract(const Duration(days: 29)),
      AttendanceRange.all => null,
      AttendanceRange.custom => customStart ?? today,
    };
  }

  /// The day after the last one included, or null for no upper bound.
  DateTime? endExclusive(DateTime now) {
    if (range != AttendanceRange.custom) return null;
    final end = customEnd ?? now;
    return DateTime(end.year, end.month, end.day + 1);
  }

  /// Matching check-ins, newest first.
  List<Attendance> apply(
    Iterable<Attendance> records, {
    required Map<String, String> namesById,
    required Map<String, SessionEntry> sessionsByTitle,
    required DateTime now,
  }) {
    final start = startDay(now);
    final end = endExclusive(now);
    final q = query.trim().toLowerCase();
    return records.where((r) {
      if (start != null && r.timestamp.isBefore(start)) return false;
      if (end != null && !r.timestamp.isBefore(end)) return false;
      if (session != null && r.sessionTitle != session) return false;
      if (status != null &&
          checkInStatus(
                r,
                namesById: namesById,
                sessionsByTitle: sessionsByTitle,
              ) !=
              status) {
        return false;
      }
      if (q.isEmpty) return true;
      final name = namesById[r.studentId]?.toLowerCase() ?? '';
      return name.contains(q) || r.studentId.toLowerCase().contains(q);
    }).toList()..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  Map<String, dynamic> toJson() => {
    'range': range.name,
    if (customStart != null) 'customStart': customStart!.toIso8601String(),
    if (customEnd != null) 'customEnd': customEnd!.toIso8601String(),
    'session': ?session,
    if (status != null) 'status': status!.name,
  };

  factory AttendanceFilter.fromJson(Map<String, dynamic> json) {
    T? byName<T extends Enum>(List<T> values, Object? name) =>
        values.where((v) => v.name == name).firstOrNull;
    final start = json['customStart'] as String?;
    final end = json['customEnd'] as String?;
    return AttendanceFilter(
      range:
          byName(AttendanceRange.values, json['range']) ?? AttendanceRange.week,
      customStart: start == null ? null : DateTime.parse(start),
      customEnd: end == null ? null : DateTime.parse(end),
      session: json['session'] as String?,
      status: byName(CheckInStatus.values, json['status']),
    );
  }

  /// Same filter, ignoring the search text.
  bool sameAs(AttendanceFilter other) =>
      range == other.range &&
      session == other.session &&
      status == other.status &&
      (range != AttendanceRange.custom ||
          (_sameDay(customStart, other.customStart) &&
              _sameDay(customEnd, other.customEnd)));

  static bool _sameDay(DateTime? a, DateTime? b) =>
      a == null ? b == null : b != null && isSameDay(a, b);
}

/// A named filter the admin saved to reuse.
class SavedAttendanceFilter {
  const SavedAttendanceFilter({required this.name, required this.filter});

  final String name;
  final AttendanceFilter filter;

  Map<String, dynamic> toJson() => {'name': name, 'filter': filter.toJson()};

  factory SavedAttendanceFilter.fromJson(Map<String, dynamic> json) =>
      SavedAttendanceFilter(
        name: json['name'] as String,
        filter: AttendanceFilter.fromJson(
          (json['filter'] as Map).cast<String, dynamic>(),
        ),
      );
}

String statusLabel(CheckInStatus status) => switch (status) {
  CheckInStatus.onTime => 'On time',
  CheckInStatus.late => 'Late',
  CheckInStatus.general => 'General',
  CheckInStatus.unknownStudent => 'Unknown student',
};

String rangeLabel(AttendanceFilter f, DateTime now) => switch (f.range) {
  AttendanceRange.today => 'Today',
  AttendanceRange.week => 'Last 7 days',
  AttendanceRange.month => 'Last 30 days',
  AttendanceRange.all => 'All time',
  AttendanceRange.custom =>
    '${formatShortDate(f.customStart ?? now, now)} – '
        '${formatShortDate(f.customEnd ?? now, now)}',
};

/// One CSV line per check-in, with a header row. Cells are always quoted
/// so names with commas or quotes survive.
String attendanceCsv(
  List<Attendance> records, {
  required Map<String, String> namesById,
  required Map<String, SessionEntry> sessionsByTitle,
}) {
  String cell(String v) => '"${v.replaceAll('"', '""')}"';
  String two(int n) => n.toString().padLeft(2, '0');
  final lines = <String>[
    [
      'date',
      'time',
      'student_id',
      'student_name',
      'session',
      'room',
      'status',
      'scan_ms',
    ].join(','),
    for (final r in records)
      [
        '${r.timestamp.year}-${two(r.timestamp.month)}-${two(r.timestamp.day)}',
        '${two(r.timestamp.hour)}:${two(r.timestamp.minute)}:${two(r.timestamp.second)}',
        r.studentId,
        namesById[r.studentId] ?? '',
        r.sessionTitle ?? '',
        r.room ?? '',
        statusLabel(
          checkInStatus(
            r,
            namesById: namesById,
            sessionsByTitle: sessionsByTitle,
          ),
        ),
        r.latencyMs?.toString() ?? '',
      ].map(cell).join(','),
  ];
  return '${lines.join('\r\n')}\r\n';
}
