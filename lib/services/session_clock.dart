import '../models/session_entry.dart';

/// How long after a session starts a check-in still counts as on time.
const Duration lateGracePeriod = Duration(minutes: 15);

int minuteOfDay(DateTime time) => time.hour * 60 + time.minute;

/// The session running at [now], if any.
SessionEntry? activeSessionAt(List<SessionEntry> sessions, DateTime now) {
  final minute = minuteOfDay(now);
  for (final s in sessions) {
    if (minute >= s.startMinuteOfDay && minute <= s.endMinuteOfDay) return s;
  }
  return null;
}

/// The next session later today, if any.
SessionEntry? nextSessionAfter(List<SessionEntry> sessions, DateTime now) {
  final minute = minuteOfDay(now);
  SessionEntry? next;
  for (final s in sessions) {
    if (s.startMinuteOfDay > minute &&
        (next == null || s.startMinuteOfDay < next.startMinuteOfDay)) {
      next = s;
    }
  }
  return next;
}

/// Whether a check-in at [time] is past [session]'s grace period.
bool isLateFor(SessionEntry session, DateTime time) =>
    minuteOfDay(time) > session.startMinuteOfDay + lateGracePeriod.inMinutes;

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// "9:02 AM"
String formatClock(DateTime time) => formatMinuteOfDay(minuteOfDay(time));

/// 542 → "9:02 AM"
String formatMinuteOfDay(int minute) {
  final h24 = minute ~/ 60;
  final m = (minute % 60).toString().padLeft(2, '0');
  final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
  return '$h12:$m ${h24 < 12 ? 'AM' : 'PM'}';
}

/// "9:00 – 10:30 AM", or "11:00 AM – 12:30 PM" across noon.
String formatSessionRange(SessionEntry s) {
  final start = formatMinuteOfDay(s.startMinuteOfDay);
  final end = formatMinuteOfDay(s.endMinuteOfDay);
  final samePeriod = (s.startMinuteOfDay < 720) == (s.endMinuteOfDay < 720);
  return samePeriod
      ? '${start.substring(0, start.length - 3)} – $end'
      : '$start – $end';
}
