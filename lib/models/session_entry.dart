/// A class meeting the kiosk takes check-ins for.
///
/// Either recurring on [weekdays] every week, or a one-off on [date].
/// Sessions saved before repeat days existed have neither and run every
/// day, as they always did.
class SessionEntry {
  final String id;
  final String title;
  final String room;
  final int startMinuteOfDay;
  final int endMinuteOfDay;
  final int expected;

  /// `DateTime.weekday` values (1 = Monday … 7 = Sunday). Ignored for
  /// one-off sessions.
  final Set<int> weekdays;

  /// Set for a one-off session: the only day it runs.
  final DateTime? date;

  /// Minutes after the start when a check-in stops counting as on time.
  final int lateAfterMinutes;

  static const int defaultLateAfterMinutes = 15;
  static const Set<int> everyDay = {1, 2, 3, 4, 5, 6, 7};

  const SessionEntry({
    required this.id,
    required this.title,
    required this.room,
    required this.startMinuteOfDay,
    required this.endMinuteOfDay,
    required this.expected,
    this.weekdays = everyDay,
    this.date,
    this.lateAfterMinutes = defaultLateAfterMinutes,
  });

  bool get isOneOff => date != null;

  /// Whether the session meets on [day].
  bool occursOn(DateTime day) {
    final d = date;
    if (d != null) {
      return d.year == day.year && d.month == day.month && d.day == day.day;
    }
    return weekdays.contains(day.weekday);
  }

  SessionEntry copyWith({
    String? title,
    String? room,
    int? startMinuteOfDay,
    int? endMinuteOfDay,
    int? expected,
    Set<int>? weekdays,
    DateTime? date,
    bool clearDate = false,
    int? lateAfterMinutes,
  }) {
    return SessionEntry(
      id: id,
      title: title ?? this.title,
      room: room ?? this.room,
      startMinuteOfDay: startMinuteOfDay ?? this.startMinuteOfDay,
      endMinuteOfDay: endMinuteOfDay ?? this.endMinuteOfDay,
      expected: expected ?? this.expected,
      weekdays: weekdays ?? this.weekdays,
      date: clearDate ? null : (date ?? this.date),
      lateAfterMinutes: lateAfterMinutes ?? this.lateAfterMinutes,
    );
  }

  factory SessionEntry.fromJson(Map<String, dynamic> json) {
    final days = (json['weekdays'] as List?)?.cast<int>().toSet();
    final date = json['date'] as String?;
    return SessionEntry(
      id: json['id'] as String,
      title: json['title'] as String,
      room: json['room'] as String,
      startMinuteOfDay: json['startMinuteOfDay'] as int,
      endMinuteOfDay: json['endMinuteOfDay'] as int,
      expected: json['expected'] as int? ?? 0,
      weekdays: days == null || days.isEmpty ? everyDay : days,
      date: date == null ? null : DateTime.parse(date),
      lateAfterMinutes:
          json['lateAfterMinutes'] as int? ?? defaultLateAfterMinutes,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'room': room,
    'startMinuteOfDay': startMinuteOfDay,
    'endMinuteOfDay': endMinuteOfDay,
    'expected': expected,
    'weekdays': (weekdays.toList()..sort()),
    if (date != null)
      'date': DateTime(date!.year, date!.month, date!.day).toIso8601String(),
    'lateAfterMinutes': lateAfterMinutes,
  };
}
