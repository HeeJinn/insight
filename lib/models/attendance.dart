import 'package:hive_ce/hive.dart';

part 'attendance.g.dart';

@HiveType(typeId: 1)
class Attendance extends HiveObject {
  @HiveField(0)
  String studentId;

  @HiveField(1)
  DateTime timestamp;

  @HiveField(2)
  String? sessionTitle;

  @HiveField(3)
  String? room;

  /// Milliseconds from frame capture to this record being saved. Null for
  /// records created before timing was added.
  @HiveField(4)
  int? latencyMs;

  Attendance({
    required this.studentId,
    required this.timestamp,
    this.sessionTitle,
    this.room,
    this.latencyMs,
  });
}
