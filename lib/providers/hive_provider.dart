import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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

  // Register adapters safely
  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(StudentAdapter());
  }
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(AttendanceAdapter());
  }
});

const _plainStudents = 'students';
const _secureStudents = 'students_secure';
const _studentsKeyName = 'insight_students_box_key_v1';

/// Students and their face profiles. Face profiles are biometric data, so
/// the box is encrypted with a key kept in the system keychain (Keychain on
/// Apple platforms, Credential Manager on Windows, Keystore on Android).
final studentsBoxProvider = FutureProvider<Box<Student>>((ref) async {
  await ref.watch(hiveInitProvider.future);
  if (kIsWeb) return Hive.openBox<Student>(_plainStudents);
  final List<int> key;
  try {
    key = await _studentsKey(const FlutterSecureStorage());
  } catch (e) {
    // shortcut: with no usable keychain the profiles stay unencrypted, as
    // before, rather than locking the admin out; fix keychain access on
    // that machine (e.g. the macOS entitlement) to get encryption back.
    debugPrint('Keychain unavailable; students box stays unencrypted: $e');
    return Hive.openBox<Student>(_plainStudents);
  }
  return openEncryptedStudents(key);
});

Future<List<int>> _studentsKey(FlutterSecureStorage storage) async {
  final saved = await storage.read(key: _studentsKeyName);
  if (saved != null) return base64Decode(saved);
  // A new key can't read the existing encrypted box, and Hive would treat
  // it as corrupt; leave the file for restoring rather than overwrite it.
  if (await Hive.boxExists(_secureStudents)) {
    throw StateError('The key for the encrypted students box is missing.');
  }
  final key = Hive.generateSecureKey();
  await storage.write(key: _studentsKeyName, value: base64Encode(key));
  return key;
}

/// Opens the encrypted students box with [key], first copying over any
/// profiles from the unencrypted box earlier versions kept. That box is
/// deleted only once every entry is in the encrypted one.
@visibleForTesting
Future<Box<Student>> openEncryptedStudents(List<int> key) async {
  final secure = await Hive.openBox<Student>(
    _secureStudents,
    encryptionCipher: HiveAesCipher(key),
  );
  if (await Hive.boxExists(_plainStudents)) {
    final plain = await Hive.openBox<Student>(_plainStudents);
    // A HiveObject lives in one box, so each moves as a copy.
    await secure.putAll({
      for (final e in plain.toMap().entries)
        e.key: Student(
          id: e.value.id,
          name: e.value.name,
          embeddings: e.value.embeddings,
        ),
    });
    await secure.flush();
    if (plain.keys.every(secure.containsKey)) {
      await plain.deleteFromDisk();
    } else {
      await plain.close();
    }
  }
  return secure;
}

// Provider for attendance box
final attendanceBoxProvider = FutureProvider<Box<Attendance>>((ref) async {
  await ref.watch(hiveInitProvider.future);
  return await Hive.openBox<Attendance>('attendance');
});
