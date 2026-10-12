import 'package:hive_ce/hive.dart';

part 'student.g.dart';

@HiveType(typeId: 0)
class Student extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  List<List<double>> embeddings; // 5 baseline embeddings, each 192-D (MobileFaceNet)

  /// When the student was first enrolled, so class days before it don't
  /// count as absences. Null for students enrolled before this was kept.
  @HiveField(3)
  DateTime? enrolledAt;

  Student({
    required this.id,
    required this.name,
    required this.embeddings,
    this.enrolledAt,
  });
}
