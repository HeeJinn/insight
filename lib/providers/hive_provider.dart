import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';
import 'package:path_provider/path_provider.dart';
import '../models/student.dart';
import '../models/attendance.dart';

// Provider for Hive initialization
final hiveInitProvider = FutureProvider<void>((ref) async {
  if (!kIsWeb) {
    final appDocumentDir = await getApplicationDocumentsDirectory();
    Hive.init(appDocumentDir.path);
  } else {
    Hive.init('');
  }

  // Register adapters
  Hive.registerAdapter(StudentAdapter());
  Hive.registerAdapter(AttendanceAdapter());
});

// Provider for students box
final studentsBoxProvider = FutureProvider<Box<Student>>((ref) async {
  await ref.watch(hiveInitProvider.future);
  return await Hive.openBox<Student>('students');
});

// Provider for attendance box
final attendanceBoxProvider = FutureProvider<Box<Attendance>>((ref) async {
  await ref.watch(hiveInitProvider.future);
  return await Hive.openBox<Attendance>('attendance');
});
