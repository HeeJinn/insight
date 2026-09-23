import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:insight/services/face_pose.dart';

/// Landmarks of a simple 3D head (x right, y down, z toward the camera),
/// rotated and orthographically projected to pixels. [yawDeg] turns the
/// head, [pitchDeg] > 0 looks up, [rollDeg] tilts it sideways.
List<math.Point<double>> _project({
  double yawDeg = 0,
  double pitchDeg = 0,
  double rollDeg = 0,
  bool mirrored = false,
}) {
  const model = [
    [-0.5, 0.0, 0.0], // right eye (image left)
    [0.5, 0.0, 0.0], // left eye
    [0.0, 0.55, 0.6], // nose tip
    [0.0, 1.15, 0.1], // mouth centre
  ];
  final yaw = yawDeg * math.pi / 180;
  final pitch = pitchDeg * math.pi / 180;
  final roll = rollDeg * math.pi / 180;
  return [
    for (final p in model)
      () {
        // Yaw about the vertical axis.
        var x = p[0] * math.cos(yaw) + p[2] * math.sin(yaw);
        var y = p[1];
        var z = -p[0] * math.sin(yaw) + p[2] * math.cos(yaw);
        // Pitch about the horizontal axis (looking up moves the nose up).
        final y2 = y * math.cos(pitch) - z * math.sin(pitch);
        z = y * math.sin(pitch) + z * math.cos(pitch);
        y = y2;
        // Roll in the image plane.
        final x3 = x * math.cos(roll) - y * math.sin(roll);
        final y3 = x * math.sin(roll) + y * math.cos(roll);
        x = mirrored ? -x3 : x3;
        return math.Point(320 + x * 100, 240 + y3 * 100);
      }(),
  ];
}

FacePose _pose({
  double yawDeg = 0,
  double pitchDeg = 0,
  double rollDeg = 0,
  bool mirrored = false,
}) {
  final p = _project(
    yawDeg: yawDeg,
    pitchDeg: pitchDeg,
    rollDeg: rollDeg,
    mirrored: mirrored,
  );
  return FacePose.fromLandmarks(p[0], p[1], p[2], p[3])!;
}

FaceObservation _face({
  double yawDeg = 0,
  double pitchDeg = 0,
  double rollDeg = 0,
  List<double> box = const [0.35, 0.3, 0.3, 0.4],
  double score = 0.95,
}) {
  return FaceObservation(
    box: box,
    score: score,
    pose: _pose(yawDeg: yawDeg, pitchDeg: pitchDeg, rollDeg: rollDeg),
  );
}

void main() {
  group('FacePose', () {
    test('a straight-on face has no yaw or roll', () {
      final pose = _pose();
      expect(pose.yaw, closeTo(0, 1e-9));
      expect(pose.roll, closeTo(0, 1e-9));
      expect(pose.pitch, closeTo(0.55 / 1.15, 1e-9));
    });

    test('yaw grows with head turn, with opposite signs per side', () {
      final left = _pose(yawDeg: 30);
      final right = _pose(yawDeg: -30);
      expect(left.yaw, greaterThan(0.2));
      expect(right.yaw, lessThan(-0.2));
      expect(left.yaw, closeTo(-right.yaw, 1e-9));
      expect(_pose(yawDeg: 15).yaw.abs(), lessThan(left.yaw.abs()));
    });

    test('pitch drops looking up and rises looking down', () {
      final front = _pose().pitch;
      expect(_pose(pitchDeg: 15).pitch, lessThan(front - 0.07));
      expect(_pose(pitchDeg: -15).pitch, greaterThan(front + 0.07));
    });

    test('roll follows the eye line', () {
      expect(_pose(rollDeg: 20).roll, closeTo(20, 1e-6));
      expect(_pose(rollDeg: -10).roll, closeTo(-10, 1e-6));
    });

    test('mirrored frames give the same magnitudes', () {
      final normal = _pose(yawDeg: 25, pitchDeg: 10, rollDeg: 5);
      final mirrored = _pose(yawDeg: 25, pitchDeg: 10, rollDeg: 5, mirrored: true);
      expect(mirrored.yaw, closeTo(-normal.yaw, 1e-9));
      expect(mirrored.pitch, closeTo(normal.pitch, 1e-9));
      expect(mirrored.roll, closeTo(-normal.roll, 1e-6));
    });

    test('rejects degenerate landmarks', () {
      const p = math.Point(10.0, 10.0);
      expect(FacePose.fromLandmarks(p, p, p, p), isNull);
    });
  });

  group('PoseGuide', () {
    test('checks framing before pose', () {
      final guide = PoseGuide();
      expect(guide.check(CapturePose.front, null).hint,
          'Position your face in the frame');
      expect(guide.check(CapturePose.front, _face(score: 0.4)).ok, isFalse);
      expect(
        guide.check(CapturePose.front, _face(box: const [0.45, 0.4, 0.1, 0.15])).hint,
        'Move closer',
      );
      expect(
        guide.check(CapturePose.front, _face(box: const [0.0, 0.1, 0.3, 0.4])).hint,
        'Center your face in the frame',
      );
      expect(guide.check(CapturePose.front, _face(rollDeg: 25)).hint,
          'Keep your head level');
    });

    test('front requires looking at the camera', () {
      final guide = PoseGuide();
      expect(guide.check(CapturePose.front, _face()).ok, isTrue);
      expect(guide.check(CapturePose.front, _face(yawDeg: 25)).ok, isFalse);
    });

    test('turns must be far enough, not too far, and on opposite sides', () {
      final guide = PoseGuide()..record(CapturePose.front, _face());

      expect(guide.check(CapturePose.turnA, _face(yawDeg: 8)).hint,
          'Turn your head to one side');
      expect(guide.check(CapturePose.turnA, _face(yawDeg: 55)).hint,
          'Too far, turn back slightly');
      expect(guide.check(CapturePose.turnA, _face(yawDeg: -30)).ok, isTrue);

      guide.record(CapturePose.turnA, _face(yawDeg: -30));
      expect(guide.check(CapturePose.turnB, _face(yawDeg: -30)).hint,
          'Turn to the other side');
      expect(guide.check(CapturePose.turnB, _face(yawDeg: 12)).hint,
          'Turn a little more');
      expect(guide.check(CapturePose.turnB, _face(yawDeg: 30)).ok, isTrue);
      // Re-checking a (possibly mirrored) still ignores the direction.
      expect(
        guide
            .check(CapturePose.turnB, _face(yawDeg: -30), ignoreDirection: true)
            .ok,
        isTrue,
      );
    });

    test('tilts are measured against the person\'s own front pose', () {
      final guide = PoseGuide()..record(CapturePose.front, _face());

      expect(guide.check(CapturePose.tiltA, _face()).hint,
          'Tilt your head up or down');
      expect(guide.check(CapturePose.tiltA, _face(pitchDeg: 15, yawDeg: 25)).hint,
          'Face forward, then tilt');
      expect(guide.check(CapturePose.tiltA, _face(pitchDeg: 15)).ok, isTrue);

      guide.record(CapturePose.tiltA, _face(pitchDeg: 15));
      expect(guide.check(CapturePose.tiltB, _face(pitchDeg: 15)).hint,
          'Tilt the other way');
      expect(guide.check(CapturePose.tiltB, _face(pitchDeg: -15)).ok, isTrue);
    });

    test('a manual front capture without a face still allows turns', () {
      final guide = PoseGuide()..record(CapturePose.front, null);
      expect(guide.check(CapturePose.turnA, _face(yawDeg: 30)).ok, isTrue);
    });
  });
}
