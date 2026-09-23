import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:insight/models/student.dart';
import 'package:insight/services/face_processor.dart';

/// Unit vector of length [FaceProcessor.embeddingLength] pointing mostly
/// along [axis], nudged toward [towards] by [mix] (0..1).
List<double> _vec(int axis, {int? towards, double mix = 0}) {
  final v = List<double>.filled(FaceProcessor.embeddingLength, 0);
  v[axis] = 1 - mix;
  if (towards != null) v[towards] = mix;
  final n = math.sqrt(v.fold<double>(0, (s, x) => s + x * x));
  return [for (final x in v) x / n];
}

void main() {
  final processor = FaceProcessor();

  final alice = Student(
    id: 'A-001',
    name: 'Alice',
    embeddings: [_vec(0), _vec(0, towards: 5, mix: 0.1)],
  );
  final bob = Student(
    id: 'B-002',
    name: 'Bob',
    embeddings: [_vec(1), _vec(1, towards: 6, mix: 0.1)],
  );

  test('matches the closest student under the threshold', () async {
    final id = await processor.recognizeStudent(
      [alice, bob],
      _vec(0, towards: 7, mix: 0.2),
    );
    expect(id, 'A-001');
  });

  test('rejects a face that is far from everyone', () async {
    final id = await processor.recognizeStudent([alice, bob], _vec(20));
    expect(id, isNull);
  });

  test('rejects an ambiguous face between two students', () async {
    // Equidistant from Alice and Bob, so the ambiguity margin fails even
    // with a permissive threshold.
    final id = await processor.recognizeStudent(
      [alice, bob],
      _vec(0, towards: 1, mix: 0.5),
      threshold: 1.4,
    );
    expect(id, isNull);
  });

  test('ignores baselines from the old pipeline', () async {
    final legacy = Student(
      id: 'L-003',
      name: 'Legacy',
      embeddings: [List<double>.filled(304, 0.1)],
    );
    expect(FaceProcessor.hasCompatibleEmbeddings(legacy), isFalse);
    expect(FaceProcessor.hasCompatibleEmbeddings(alice), isTrue);

    final id = await processor.recognizeStudent([legacy, alice], _vec(0));
    expect(id, 'A-001');
  });

  test('uses the mirrored embedding as an alternate candidate', () async {
    final id = await processor.recognizeStudent(
      [alice, bob],
      _vec(30),
      alternateEmbeddings: [_vec(1)],
    );
    expect(id, 'B-002');
  });
}
