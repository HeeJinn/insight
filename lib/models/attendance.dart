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
  /// records created before timing was added, and for ones an admin made.
  @HiveField(4)
  int? latencyMs;

  /// Marked excused by an admin: the student was absent with leave. Left
  /// out of attendance rates rather than counted present or absent.
  @HiveField(5)
  bool excused;

  /// Face-match distance to the recognized student (lower is closer), for
  /// evaluating the threshold. Null for records not made by the camera.
  @HiveField(6)
  double? matchDistance;

  /// How much closer the recognized student was than the runner-up.
  /// Infinite with only one candidate; null when not made by the camera.
  @HiveField(7)
  double? matchMargin;

  Attendance({
    required this.studentId,
    required this.timestamp,
    this.sessionTitle,
    this.room,
    this.latencyMs,
    this.excused = false,
    this.matchDistance,
    this.matchMargin,
  });
}
