import '../models/session_entry.dart';

int minuteOfDay(DateTime time) => time.hour * 60 + time.minute;

/// Sessions that meet on [day], earliest first. One-offs sort ahead of
/// recurring sessions at the same time, since they override the schedule.
List<SessionEntry> sessionsOn(List<SessionEntry> sessions, DateTime day) {
  return sessions.where((s) => s.occursOn(day)).toList()..sort((a, b) {
    final byStart = a.startMinuteOfDay.compareTo(b.startMinuteOfDay);
    if (byStart != 0) return byStart;
    return (a.isOneOff ? 0 : 1).compareTo(b.isOneOff ? 0 : 1);
  });
}

/// The session running at [now], if any. A one-off running at the same
/// time as a recurring session takes precedence.
SessionEntry? activeSessionAt(List<SessionEntry> sessions, DateTime now) {
  final minute = minuteOfDay(now);
  SessionEntry? found;
  for (final s in sessionsOn(sessions, now)) {
    if (minute >= s.startMinuteOfDay && minute <= s.endMinuteOfDay) {
      if (s.isOneOff) return s;
      found ??= s;
    }
  }
  return found;
}

/// The next session later today, if any.
SessionEntry? nextSessionAfter(List<SessionEntry> sessions, DateTime now) {
  final minute = minuteOfDay(now);
  for (final s in sessionsOn(sessions, now)) {
    if (s.startMinuteOfDay > minute) return s;
  }
  return null;
}

/// Whether a check-in at [time] is past [session]'s late cutoff.
bool isLateFor(SessionEntry session, DateTime time) =>
    minuteOfDay(time) > session.startMinuteOfDay + session.lateAfterMinutes;

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

const _dayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _monthShort = [
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

/// "Every day", "Weekdays", "Weekends", or "Mon, Wed, Fri".
String formatWeekdays(Set<int> days) {
  if (days.length == 7) return 'Every day';
  if (days.length == 5 && days.containsAll({1, 2, 3, 4, 5})) return 'Weekdays';
  if (days.length == 2 && days.containsAll({6, 7})) return 'Weekends';
  final sorted = days.toList()..sort();
  return sorted.map((d) => _dayShort[d - 1]).join(', ');
}

/// "Mon, Sep 28", with the year when it isn't [now]'s.
String formatShortDate(DateTime date, DateTime now) {
  final base =
      '${_dayShort[date.weekday - 1]}, ${_monthShort[date.month - 1]} ${date.day}';
  return date.year == now.year ? base : '$base, ${date.year}';
}

/// When [session] meets: "Mon, Wed, Fri" or "Today" / "Mon, Sep 28".
String formatRecurrence(SessionEntry session, DateTime now) {
  final d = session.date;
  if (d == null) return formatWeekdays(session.weekdays);
  if (isSameDay(d, now)) return 'Today';
  if (isSameDay(d, now.add(const Duration(days: 1)))) return 'Tomorrow';
  return formatShortDate(d, now);
}
