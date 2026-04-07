import 'package:hive_ce/hive.dart';

part 'student.g.dart';

@HiveType(typeId: 0)
class Student extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  List<List<double>> embeddings; // List of 5 embeddings, each 128D

  Student({required this.id, required this.name, required this.embeddings});
}
