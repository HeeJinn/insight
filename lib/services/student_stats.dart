import '../models/attendance.dart';
import '../models/student.dart';
import '../services/face_processor.dart';
import 'session_clock.dart';

/// Whether a student's face profile can be matched by the current model.
enum FaceProfileStatus {
  ready,

  /// Enrolled with an older pipeline; the kiosk can't recognize them until
  /// they are enrolled again.
  needsReEnrollment,

  /// No face data at all.
  missing,
}

FaceProfileStatus faceProfileStatus(Student s) {
  if (s.embeddings.isEmpty) return FaceProfileStatus.missing;
  return FaceProcessor.hasCompatibleEmbeddings(s)
      ? FaceProfileStatus.ready
      : FaceProfileStatus.needsReEnrollment;
}

/// One student's attendance history, newest first.
class StudentStats {
  StudentStats._(this.records, this.now);

  factory StudentStats.of(
    String studentId,
    Iterable<Attendance> attendance, {
    DateTime? now,
  }) {
    final records = attendance.where((a) => a.studentId == studentId).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return StudentStats._(records, now ?? DateTime.now());
  }

  final List<Attendance> records;
  final DateTime now;

  DateTime? get lastSeen => records.isEmpty ? null : records.first.timestamp;

  int get total => records.length;

  /// Distinct days with a check-in in the last [days] days, today included.
  int daysPresentInLast(int days) {
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: days - 1));
    return records
        .where((r) => !r.timestamp.isBefore(start))
        .map(
          (r) => DateTime(r.timestamp.year, r.timestamp.month, r.timestamp.day),
        )
        .toSet()
        .length;
  }

  bool get checkedInToday =>
      records.isNotEmpty && isSameDay(records.first.timestamp, now);
}

/// "Today, 9:02 AM", "Yesterday", "Mon", or "Sep 3".
String formatLastSeen(DateTime? time, DateTime now) {
  if (time == null) return 'Never';
  if (isSameDay(time, now)) return 'Today, ${formatClock(time)}';
  final yesterday = now.subtract(const Duration(days: 1));
  if (isSameDay(time, yesterday)) return 'Yesterday';
  final days = DateTime(
    now.year,
    now.month,
    now.day,
  ).difference(DateTime(time.year, time.month, time.day)).inDays;
  if (days < 7) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[time.weekday - 1];
  }
  const months = [
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
  final sameYear = time.year == now.year;
  return '${months[time.month - 1]} ${time.day}${sameYear ? '' : ', ${time.year}'}';
}
