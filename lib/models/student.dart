import 'package:hive_ce/hive.dart';

part 'student.g.dart';

/// The programs a student can be enrolled in.
const programs = [
  'BS Civil Engineering',
  'BS Accountancy',
  'BS Accounting Technology',
  'BS Nursing',
  'BS Medical Laboratory Science (MedTech)',
  'BS Criminology',
  'BS Tourism Management',
  'BS Architecture',
  'BS Computer Science',
  'AB English Language',
  'Entrepreneurship',
];

/// Year levels go to 5 for the five-year programs (engineering,
/// architecture).
const maxYearLevel = 5;

/// "1st Year", "2nd Year", …
String yearLevelLabel(int year) =>
    '$year${switch (year) {
      1 => 'st',
      2 => 'nd',
      3 => 'rd',
      _ => 'th',
    }} Year';

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

  /// One of [programs]. Null for students enrolled before it was asked.
  @HiveField(4)
  String? program;

  /// 1 to [maxYearLevel]. Null for students enrolled before it was asked.
  @HiveField(5)
  int? yearLevel;

  /// Optional, as the school writes it ("A", "1", …).
  @HiveField(6)
  String? section;

  Student({
    required this.id,
    required this.name,
    required this.embeddings,
    this.enrolledAt,
    this.program,
    this.yearLevel,
    this.section,
  });

  /// "BS Nursing · 2nd Year · Section B", or null when none are set.
  String? get groupLabel {
    final parts = [
      ?program,
      if (yearLevel != null) yearLevelLabel(yearLevel!),
      if (section != null) 'Section $section',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}
