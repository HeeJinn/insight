import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_face_mesh_detection/google_mlkit_face_mesh_detection.dart';

import '../services/live_face_tracker.dart';

/// Draws a live-tracking overlay for the most recent [LiveFaceTrackingFrame]:
/// a face-mesh wireframe on Android, a contour outline on iOS, or a tracked
/// bounding box on Windows. Replaces a static decorative frame with one that
/// actually follows the detected face.
class FaceTrackingOverlayPainter extends CustomPainter {
  final LiveFaceTrackingFrame? frame;
  final Color color;

  const FaceTrackingOverlayPainter({required this.frame, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final frame = this.frame;
    if (frame == null) {
      return;
    }

    final geometry = frame.geometry;
    if (geometry is MeshFaceGeometry) {
      _paintMesh(canvas, size, frame, geometry);
    } else if (geometry is ContourFaceGeometry) {
      _paintContours(canvas, size, frame, geometry);
    } else if (geometry is NormalizedBoxGeometry) {
      _paintNormalizedBox(canvas, size, geometry);
    }
  }

  void _paintMesh(
    Canvas canvas,
    Size size,
    LiveFaceTrackingFrame frame,
    MeshFaceGeometry geometry,
  ) {
    final wirePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = color.withValues(alpha: 0.55);

    // A full mesh has ~800 triangles; building one Path per triangle (and
    // one drawPath call each) allocates hundreds of objects per repaint for
    // no benefit here, since they all share one paint. One combined Path
    // with a moveTo per triangle draws identically in a single canvas call.
    final path = Path();
    for (final triangle in geometry.triangles) {
      if (triangle.points.length < 3) {
        continue;
      }
      for (var i = 0; i < triangle.points.length; i++) {
        final point = triangle.points[i];
        final offset = _mapPoint(
          point.x,
          point.y,
          size,
          frame.imageSize,
          frame.rotation,
        );
        if (i == 0) {
          path.moveTo(offset.dx, offset.dy);
        } else {
          path.lineTo(offset.dx, offset.dy);
        }
      }
      path.close();
    }
    canvas.drawPath(path, wirePaint);
  }

  void _paintContours(
    Canvas canvas,
    Size size,
    LiveFaceTrackingFrame frame,
    ContourFaceGeometry geometry,
  ) {
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = color;

    final path = Path();
    for (final contour in geometry.contours.values) {
      if (contour == null || contour.points.isEmpty) {
        continue;
      }
      for (var i = 0; i < contour.points.length; i++) {
        final point = contour.points[i];
        final offset = _mapPoint(
          point.x.toDouble(),
          point.y.toDouble(),
          size,
          frame.imageSize,
          frame.rotation,
        );
        if (i == 0) {
          path.moveTo(offset.dx, offset.dy);
        } else {
          path.lineTo(offset.dx, offset.dy);
        }
      }
    }
    canvas.drawPath(path, linePaint);
  }

  void _paintNormalizedBox(Canvas canvas, Size size, NormalizedBoxGeometry geometry) {
    final rect = Rect.fromLTWH(
      geometry.left * size.width,
      geometry.top * size.height,
      geometry.width * size.width,
      geometry.height * size.height,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..color = color;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(18)), paint);
  }

  /// Maps a point from raw camera-frame pixel space (what ML Kit reports)
  /// to this painter's canvas space.
  ///
  /// Ported from the official ML Kit Flutter example's
  /// `coordinates_translator.dart`, with one deliberate change: upstream
  /// mirrors the 0deg/180deg case horizontally for front cameras, to match
  /// a conventionally-mirrored selfie preview. This app never mirrors its
  /// [CameraPreview] (see `CoverCameraPreview`), so mirroring there would
  /// offset the overlay to the wrong side of the real face — it's
  /// intentionally omitted. The 90deg/270deg cases are left exactly as
  /// upstream: their axis swap and reflection are inherent to those
  /// rotations, not a mirroring convention.
  Offset _mapPoint(
    double x,
    double y,
    Size canvasSize,
    Size imageSize,
    InputImageRotation rotation,
  ) {
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final double mappedX;
    final double mappedY;

    switch (rotation) {
      case InputImageRotation.rotation90deg:
        mappedX = x * canvasSize.width / (isIOS ? imageSize.width : imageSize.height);
        mappedY = y * canvasSize.height / (isIOS ? imageSize.height : imageSize.width);
      case InputImageRotation.rotation270deg:
        mappedX =
            canvasSize.width -
            x * canvasSize.width / (isIOS ? imageSize.width : imageSize.height);
        mappedY = y * canvasSize.height / (isIOS ? imageSize.height : imageSize.width);
      case InputImageRotation.rotation0deg:
      case InputImageRotation.rotation180deg:
        mappedX = x * canvasSize.width / imageSize.width;
        mappedY = y * canvasSize.height / imageSize.height;
    }

    return Offset(mappedX, mappedY);
  }

  @override
  bool shouldRepaint(covariant FaceTrackingOverlayPainter oldDelegate) {
    return oldDelegate.frame != frame;
  }
}
