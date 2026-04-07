class SessionEntry {
  final String id;
  final String title;
  final String room;
  final int startMinuteOfDay;
  final int endMinuteOfDay;
  final int expected;

  const SessionEntry({
    required this.id,
    required this.title,
    required this.room,
    required this.startMinuteOfDay,
    required this.endMinuteOfDay,
    required this.expected,
  });

  factory SessionEntry.fromJson(Map<String, dynamic> json) {
    return SessionEntry(
      id: json['id'] as String,
      title: json['title'] as String,
      room: json['room'] as String,
      startMinuteOfDay: json['startMinuteOfDay'] as int,
      endMinuteOfDay: json['endMinuteOfDay'] as int,
      expected: json['expected'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'room': room,
        'startMinuteOfDay': startMinuteOfDay,
        'endMinuteOfDay': endMinuteOfDay,
        'expected': expected,
      };

  String get timeLabel {
    String fmt(int minute) {
      final h = (minute ~/ 60).toString().padLeft(2, '0');
      final m = (minute % 60).toString().padLeft(2, '0');
      return '$h:$m';
    }

    return '${fmt(startMinuteOfDay)} - ${fmt(endMinuteOfDay)}';
  }
}
