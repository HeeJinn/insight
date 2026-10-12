import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:insight/models/student.dart';
import 'package:insight/providers/hive_provider.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('insight_crypto');
    Hive.init(dir.path);
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(StudentAdapter());
  });
  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  test('moves plain profiles into the encrypted box, then deletes them', () async {
    final plain = await Hive.openBox<Student>('students');
    await plain.put(
      's1',
      Student(
        id: 's1',
        name: 'Maria Santos',
        embeddings: [
          [0.25, -0.5],
        ],
      ),
    );
    await plain.close();

    final key = Hive.generateSecureKey();
    final secure = await openEncryptedStudents(key);
    expect(secure.get('s1')?.name, 'Maria Santos');
    expect(await Hive.boxExists('students'), isFalse);

    // The file on disk no longer holds the name in the clear.
    await secure.close();
    final bytes = await File('${dir.path}/students_secure.hive').readAsBytes();
    expect(String.fromCharCodes(bytes).contains('Maria Santos'), isFalse);

    final again = await openEncryptedStudents(key);
    expect(again.get('s1')?.embeddings, [
      [0.25, -0.5],
    ]);
  });
}
