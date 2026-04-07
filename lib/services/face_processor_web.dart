import 'package:image/image.dart' as img;
import 'package:camera/camera.dart';
import '../models/student.dart';

class FaceProcessor {
  Future<void> loadModels() async {}

  img.Image convertCameraImage(CameraImage cameraImage) {
    throw UnsupportedError('Face processing is not supported on web.');
  }

  Future<List<double>> detectFace(img.Image image) async {
    throw UnsupportedError('Face processing is not supported on web.');
  }

  Future<List<double>> recognizeFace(img.Image faceImage) async {
    throw UnsupportedError('Face processing is not supported on web.');
  }

  Future<List<List<double>>> processBaselinePhotos(List<dynamic> photos) async {
    throw UnsupportedError('Face processing is not supported on web.');
  }

  img.Image cropFace(img.Image image, List<double> bbox) => image;

  Future<String?> recognizeStudent(
    List<Student> students,
    List<double> liveEmbedding, {
    double threshold = 0.8,
  }) async {
    return null;
  }

  void dispose() {}
}
