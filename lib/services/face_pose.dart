import 'dart:math' as math;

/// Rough head pose estimated from BlazeFace's 2D landmarks.
///
/// The three values are ratios rather than calibrated angles — six 2D
/// points can't give true degrees — but they move monotonically with head
/// rotation, which is all the guided capture needs. Approximate degree
/// equivalents are noted on the thresholds in [PoseGuide].
class FacePose {
  const FacePose({required this.yaw, required this.pitch, required this.roll});

  /// Estimates the pose from landmarks in pixel coordinates (not
  /// normalized — x and y must share a scale): right eye, left eye, nose
  /// tip, mouth centre. Returns null for degenerate input.
  static FacePose? fromLandmarks(
    math.Point<double> rightEye,
    math.Point<double> leftEye,
    math.Point<double> nose,
    math.Point<double> mouth,
  ) {
    var ux = leftEye.x - rightEye.x;
    var uy = leftEye.y - rightEye.y;
    final eyeDistance = math.sqrt(ux * ux + uy * uy);
    if (eyeDistance < 1e-6) {
      return null;
    }
    ux /= eyeDistance;
    uy /= eyeDistance;
    // Mirrored frames (some front cameras) put the eyes the other way
    // round. Always measure along an image-left-to-right eye axis so the
    // numbers mean the same thing either way; the guided capture only cares
    // about "one side, then the other", never which side is which.
    if (ux < 0) {
      ux = -ux;
      uy = -uy;
    }
    // Perpendicular to the eye line, pointing down the face.
    final nx = -uy;
    final ny = ux;

    final midX = (rightEye.x + leftEye.x) / 2;
    final midY = (rightEye.y + leftEye.y) / 2;
    final noseX = nose.x - midX;
    final noseY = nose.y - midY;
    final mouthDown = (mouth.x - midX) * nx + (mouth.y - midY) * ny;
    if (mouthDown < 1e-6) {
      return null;
    }

    return FacePose(
      yaw: (noseX * ux + noseY * uy) / eyeDistance,
      pitch: (noseX * nx + noseY * ny) / mouthDown,
      roll: math.atan2(uy, ux) * 180 / math.pi,
    );
  }

  /// Sideways nose offset from the eye midpoint, in inter-eye distances.
  /// About 0 facing the camera, growing (either sign) as the head turns.
  final double yaw;

  /// How far down the nose tip sits between the eye line (0) and the mouth
  /// (1). Varies from person to person, so it is compared against the
  /// person's own straight-on value; it drops when looking up and rises
  /// when looking down.
  final double pitch;

  /// Eye-line angle in degrees; 0 when the head is level.
  final double roll;
}

/// One detected face: where it is and how it's posed.
class FaceObservation {
  const FaceObservation({
    required this.box,
    required this.score,
    required this.pose,
  });

  /// `[x, y, width, height]` normalized (0..1) to the image.
  final List<double> box;

  /// Detector confidence (0..1).
  final double score;

  final FacePose pose;
}

/// The five baseline angles captured at registration.
enum CapturePose { front, turnA, turnB, tiltA, tiltB }

/// Result of checking a face against a [CapturePose].
class PoseCheck {
  const PoseCheck.ok() : ok = true, hint = 'Hold still';
  const PoseCheck.fail(this.hint) : ok = false;

  final bool ok;

  /// What the person should do next.
  final String hint;
}

/// Decides whether a face is in the right pose for each guided capture
/// step.
///
/// Turns and tilts are measured relative to the person's own straight-on
/// pose from the [CapturePose.front] step, and the second turn/tilt must go
/// the opposite way from the first.
class PoseGuide {
  static const double minScore = 0.7;
  static const double minFaceWidth = 0.18;
  static const double maxFaceWidth = 0.8;
  static const double maxCenterOffset = 0.22;
  static const double maxRoll = 15;
  static const double maxRollWhileTurning = 22;

  /// Nose offset allowed when facing the camera (about ±8°).
  static const double maxFrontYaw = 0.1;

  /// Nose offset range accepted for a turn (about 18°–45°).
  static const double minTurnYaw = 0.2;
  static const double maxTurnYaw = 0.6;

  /// Change in nose height accepted for a tilt (about 8°–35°).
  static const double minTiltPitch = 0.07;
  static const double maxTiltPitch = 0.3;

  /// Sideways turn tolerated while tilting (about ±14°).
  static const double maxYawWhileTilting = 0.15;

  /// Fallback straight-on nose height when the front step was captured
  /// manually without a detectable face.
  static const double defaultFrontPitch = 0.5;

  FacePose? _front;
  int? _turnSign;
  int? _tiltSign;

  /// Checks [face] (null when no face was found) against [target].
  ///
  /// With [ignoreDirection], a turn/tilt only has to be far enough, in
  /// either direction — used to re-check a still photo, which some cameras
  /// mirror relative to the live frames the direction was learned from.
  PoseCheck check(
    CapturePose target,
    FaceObservation? face, {
    bool ignoreDirection = false,
  }) {
    if (face == null) {
      return const PoseCheck.fail('Position your face in the frame');
    }
    if (face.score < minScore) {
      return const PoseCheck.fail('Face the camera in good light');
    }
    final width = face.box[2];
    if (width < minFaceWidth) {
      return const PoseCheck.fail('Move closer');
    }
    if (width > maxFaceWidth) {
      return const PoseCheck.fail('Move back a little');
    }
    final centerX = face.box[0] + width / 2;
    final centerY = face.box[1] + face.box[3] / 2;
    if ((centerX - 0.5).abs() > maxCenterOffset ||
        (centerY - 0.5).abs() > maxCenterOffset) {
      return const PoseCheck.fail('Center your face in the frame');
    }

    final pose = face.pose;
    final turning =
        target == CapturePose.turnA || target == CapturePose.turnB;
    if (pose.roll.abs() > (turning ? maxRollWhileTurning : maxRoll)) {
      return const PoseCheck.fail('Keep your head level');
    }

    final frontYaw = _front?.yaw ?? 0;
    final frontPitch = _front?.pitch ?? defaultFrontPitch;
    final yaw = pose.yaw - frontYaw;
    final pitch = pose.pitch - frontPitch;

    switch (target) {
      case CapturePose.front:
        if (pose.yaw.abs() > maxFrontYaw) {
          return const PoseCheck.fail('Look straight at the camera');
        }
        return const PoseCheck.ok();

      case CapturePose.turnA:
      case CapturePose.turnB:
        // The second turn must go the opposite way from the first.
        final firstSign = _turnSign;
        final required =
            target == CapturePose.turnB && !ignoreDirection && firstSign != null
                ? -firstSign
                : null;
        if (required != null && yaw.sign != required && yaw.abs() > 0.05) {
          return const PoseCheck.fail('Turn to the other side');
        }
        if (yaw.abs() < minTurnYaw) {
          return PoseCheck.fail(
            required == null ? 'Turn your head to one side' : 'Turn a little more',
          );
        }
        if (yaw.abs() > maxTurnYaw) {
          return const PoseCheck.fail('Too far, turn back slightly');
        }
        return const PoseCheck.ok();

      case CapturePose.tiltA:
      case CapturePose.tiltB:
        if (yaw.abs() > maxYawWhileTilting) {
          return const PoseCheck.fail('Face forward, then tilt');
        }
        final firstSign = _tiltSign;
        final required =
            target == CapturePose.tiltB && !ignoreDirection && firstSign != null
                ? -firstSign
                : null;
        if (required != null && pitch.sign != required && pitch.abs() > 0.03) {
          return const PoseCheck.fail('Tilt the other way');
        }
        if (pitch.abs() < minTiltPitch) {
          return PoseCheck.fail(
            required == null ? 'Tilt your head up or down' : 'Tilt a little more',
          );
        }
        if (pitch.abs() > maxTiltPitch) {
          return const PoseCheck.fail('Too far, tilt back slightly');
        }
        return const PoseCheck.ok();
    }
  }

  /// Remembers what an accepted [target] capture looked like, so later
  /// steps are measured against it. [face] may be null for a manual capture
  /// with no detectable face.
  void record(CapturePose target, FaceObservation? face) {
    if (face == null) {
      return;
    }
    final pose = face.pose;
    switch (target) {
      case CapturePose.front:
        _front = pose;
      case CapturePose.turnA:
        final yaw = pose.yaw - (_front?.yaw ?? 0);
        if (yaw.abs() > 0.05) _turnSign = yaw.sign.toInt();
      case CapturePose.tiltA:
        final pitch = pose.pitch - (_front?.pitch ?? defaultFrontPitch);
        if (pitch.abs() > 0.03) _tiltSign = pitch.sign.toInt();
      case CapturePose.turnB:
      case CapturePose.tiltB:
        break;
    }
  }
}
