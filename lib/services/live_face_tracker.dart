import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_face_mesh_detection/google_mlkit_face_mesh_detection.dart';

/// Live, per-frame face geometry used to draw a tracking overlay.
///
/// This is independent of [FaceProcessor]/the student-recognition pipeline:
/// it only drives what's drawn on screen, never who gets marked present.
sealed class TrackedFaceGeometry {
  const TrackedFaceGeometry();
}

/// Android: the full 468-point face mesh, as a set of triangles.
class MeshFaceGeometry extends TrackedFaceGeometry {
  final List<FaceMeshTriangle> triangles;
  const MeshFaceGeometry(this.triangles);
}

/// iOS: face contours (eyes, brows, lips, nose bridge, face oval), since
/// google_mlkit_face_mesh_detection is Android-only (Beta) as of this
/// writing.
class ContourFaceGeometry extends TrackedFaceGeometry {
  final Map<FaceContourType, FaceContour?> contours;
  const ContourFaceGeometry(this.contours);
}

/// Windows: a fractional (0..1) box, sourced from the existing
/// tflite-based FaceProcessor (BlazeFace) face box rather than a
/// live ML Kit stream (ML Kit has no desktop implementation).
class NormalizedBoxGeometry extends TrackedFaceGeometry {
  final double left;
  final double top;
  final double width;
  final double height;
  const NormalizedBoxGeometry({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });
}

/// One tracked-face result plus the coordinate-space info a painter needs
/// to map [geometry]'s points onto a display canvas.
///
/// [imageSize] and [rotation] are only meaningful for [MeshFaceGeometry]
/// and [ContourFaceGeometry] — they describe the raw camera frame the ML
/// Kit detector ran on. [NormalizedBoxGeometry] is already fractional and
/// ignores them.
class LiveFaceTrackingFrame {
  final TrackedFaceGeometry geometry;
  final Size imageSize;
  final InputImageRotation rotation;

  const LiveFaceTrackingFrame({
    required this.geometry,
    this.imageSize = Size.zero,
    this.rotation = InputImageRotation.rotation0deg,
  });
}

/// Runs Google ML Kit's on-device face mesh (Android) or face contour
/// (iOS) detector against live camera frames, for the sole purpose of
/// drawing a face-tracking overlay. Not supported on Windows/web/desktop —
/// ML Kit has no implementation there, so [isSupported] is false and
/// [processCameraImage] always returns null.
class LiveFaceTracker {
  FaceMeshDetector? _meshDetector;
  FaceDetector? _contourDetector;
  bool _closed = false;

  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  void _ensureDetector() {
    if (_closed) {
      return;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      _meshDetector ??= FaceMeshDetector(
        option: FaceMeshDetectorOptions.faceMesh,
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      _contourDetector ??= FaceDetector(
        options: FaceDetectorOptions(
          enableContours: true,
          performanceMode: FaceDetectorMode.fast,
        ),
      );
    }
  }

  Future<LiveFaceTrackingFrame?> processCameraImage(
    CameraImage image, {
    required CameraDescription camera,
    required DeviceOrientation deviceOrientation,
  }) async {
    if (!isSupported || _closed) {
      return null;
    }
    _ensureDetector();

    final inputImage = _buildInputImage(
      image,
      camera: camera,
      deviceOrientation: deviceOrientation,
    );
    if (inputImage == null) {
      return null;
    }

    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final meshes = await _meshDetector!.processImage(inputImage);
        if (meshes.isEmpty) {
          return null;
        }
        return LiveFaceTrackingFrame(
          geometry: MeshFaceGeometry(meshes.first.triangles),
          imageSize: inputImage.metadata!.size,
          rotation: inputImage.metadata!.rotation,
        );
      }

      final faces = await _contourDetector!.processImage(inputImage);
      if (faces.isEmpty) {
        return null;
      }
      return LiveFaceTrackingFrame(
        geometry: ContourFaceGeometry(faces.first.contours),
        imageSize: inputImage.metadata!.size,
        rotation: inputImage.metadata!.rotation,
      );
    } catch (e, stackTrace) {
      debugPrint('Live face tracking error: $e');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  static const Map<DeviceOrientation, int> _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  InputImageRotation? _rotationFor(
    CameraDescription camera,
    DeviceOrientation deviceOrientation,
  ) {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return InputImageRotationValue.fromRawValue(camera.sensorOrientation);
    }

    final base = _orientations[deviceOrientation];
    if (base == null) {
      return null;
    }
    final compensated = camera.lensDirection == CameraLensDirection.front
        ? (camera.sensorOrientation + base) % 360
        : (camera.sensorOrientation - base + 360) % 360;
    return InputImageRotationValue.fromRawValue(compensated);
  }

  InputImage? _buildInputImage(
    CameraImage image, {
    required CameraDescription camera,
    required DeviceOrientation deviceOrientation,
  }) {
    final rotation = _rotationFor(camera, deviceOrientation);
    if (rotation == null) {
      return null;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      // The shared camera stream stays on the default 3-plane YUV420
      // format (which FaceProcessor's own conversion already relies on);
      // ML Kit on Android only accepts NV21, so it's repacked here rather
      // than switching the stream's format group for every consumer.
      if (image.planes.length != 3) {
        return null;
      }
      final nv21 = _yuv420ToNv21(image);
      return InputImage.fromBytes(
        bytes: nv21,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: image.width,
        ),
      );
    }

    // iOS: the camera plugin already delivers a single bgra8888 plane by
    // default, which is exactly what ML Kit expects there — no repacking.
    if (image.planes.length != 1) {
      return null;
    }
    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.bgra8888,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  // Reused across calls instead of allocating a fresh ~100KB+ buffer for
  // every tracked frame (every ~120ms while a face is on screen). Safe to
  // overwrite between calls: processCameraImage() gates on _isTrackingFace
  // so only one conversion is ever in flight, and by the time
  // FaceMeshDetector.processImage's underlying platform-channel call
  // returns, the bytes have already been copied into the outgoing message.
  Uint8List? _nv21Buffer;

  /// Repacks a 3-plane YUV_420_888 [CameraImage] (Y, U, V separate planes)
  /// into a single NV21 buffer (Y plane, followed by interleaved V/U).
  Uint8List _yuv420ToNv21(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final ySize = width * height;
    final uvSize = (width ~/ 2) * (height ~/ 2);
    final requiredSize = ySize + uvSize * 2;
    var nv21 = _nv21Buffer;
    if (nv21 == null || nv21.length != requiredSize) {
      nv21 = Uint8List(requiredSize);
      _nv21Buffer = nv21;
    }

    var offset = 0;
    if (yPlane.bytesPerRow == width) {
      nv21.setRange(0, ySize, yPlane.bytes);
      offset = ySize;
    } else {
      for (var row = 0; row < height; row++) {
        final start = row * yPlane.bytesPerRow;
        nv21.setRange(offset, offset + width, yPlane.bytes, start);
        offset += width;
      }
    }

    final uvPixelStride = uPlane.bytesPerPixel ?? 1;
    final uvRowStride = uPlane.bytesPerRow;
    for (var row = 0; row < height ~/ 2; row++) {
      final uvRowStart = row * uvRowStride;
      for (var col = 0; col < width ~/ 2; col++) {
        final uvIndex = uvRowStart + col * uvPixelStride;
        nv21[offset++] = vPlane.bytes[uvIndex];
        nv21[offset++] = uPlane.bytes[uvIndex];
      }
    }

    return nv21;
  }

  Future<void> close() async {
    _closed = true;
    await _meshDetector?.close();
    await _contourDetector?.close();
  }
}
