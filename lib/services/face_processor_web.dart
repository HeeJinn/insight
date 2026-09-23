import 'dart:typed_data';

import 'package:camera/camera.dart';

import '../models/student.dart';
import 'face_pose.dart';

export 'face_pose.dart';

/// Web placeholder. Face processing needs native TensorFlow Lite, which is
/// not available in the browser build.
class FaceScanResult {
  const FaceScanResult({
    required this.embedding,
    required this.mirroredEmbedding,
    required this.box,
    required this.detectionScore,
    required this.processingMs,
  });

  final List<double> embedding;
  final List<double> mirroredEmbedding;
  final List<double> box;
  final double detectionScore;
  final int processingMs;
}

class FaceProcessor {
  static const String detectionModelPath =
      'assets/models/face_detection_front.tflite';
  static const String recognitionModelPath =
      'assets/models/mobile_face_net.tflite';
  static const int embeddingLength = 192;
  static const double defaultThreshold = 1.0;
  static const double ambiguityMargin = 0.12;

  static bool isCompatibleEmbedding(List<double> embedding) =>
      embedding.length == embeddingLength;

  static bool hasCompatibleEmbeddings(Student student) =>
      student.embeddings.any(isCompatibleEmbedding);

  Future<void> loadModels() async {}

  Future<FaceScanResult?> processCameraImage(
    CameraImage image, {
    int rotationDegrees = 0,
  }) async {
    throw UnsupportedError('Face processing is not supported on web.');
  }

  Future<FaceScanResult?> processEncodedImage(Uint8List bytes) async {
    throw UnsupportedError('Face processing is not supported on web.');
  }

  Future<FaceObservation?> detectCameraImage(
    CameraImage image, {
    int rotationDegrees = 0,
  }) async {
    throw UnsupportedError('Face processing is not supported on web.');
  }

  Future<FaceObservation?> detectEncodedImage(Uint8List bytes) async {
    throw UnsupportedError('Face processing is not supported on web.');
  }

  Future<List<List<double>>> processBaselinePhotos(List<dynamic> photos) async {
    throw UnsupportedError('Face processing is not supported on web.');
  }

  Future<String?> recognizeStudent(
    List<Student> students,
    List<double> liveEmbedding, {
    double threshold = defaultThreshold,
    Iterable<List<double>> alternateEmbeddings = const [],
  }) async {
    return null;
  }

  void dispose() {}
}
