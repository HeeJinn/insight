import 'dart:io';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import '../models/student.dart';

class FaceProcessor {
  Interpreter? _detectionInterpreter;
  Interpreter? _recognitionInterpreter;
  bool _detectionAvailable = true;
  bool _recognitionAvailable = true;
  bool _detectionLoadAttempted = false;
  bool _recognitionLoadAttempted = false;

  static const String detectionModelPath =
      'assets/models/face_detection_front.tflite';
  static const String recognitionModelPath =
      'assets/models/mobile_face_net.tflite';

  Future<void> loadModels() async {
    await _ensureDetectionInterpreter();
    await _ensureRecognitionInterpreter();
  }

  Future<void> _ensureDetectionInterpreter() async {
    if (_detectionLoadAttempted) {
      return;
    }

    _detectionLoadAttempted = true;
    try {
      _detectionInterpreter = await Interpreter.fromAsset(detectionModelPath);
    } catch (e, stackTrace) {
      _detectionAvailable = false;
      debugPrint('Detection model unavailable, using safe crop fallback: $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _ensureRecognitionInterpreter() async {
    if (_recognitionLoadAttempted) {
      return;
    }

    _recognitionLoadAttempted = true;
    try {
      _recognitionInterpreter = await Interpreter.fromAsset(
        recognitionModelPath,
      );
    } catch (e, stackTrace) {
      _recognitionAvailable = false;
      debugPrint('Recognition model unavailable, using fallback engine: $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  img.Image convertCameraImage(CameraImage cameraImage) {
    final int width = cameraImage.width;
    final int height = cameraImage.height;
    final img.Image image = img.Image(width: width, height: height);

    final Plane yPlane = cameraImage.planes[0];
    final Plane uPlane = cameraImage.planes[1];
    final Plane vPlane = cameraImage.planes[2];

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int yIndex = y * yPlane.bytesPerRow + x;
        final int uvIndex = (y ~/ 2) * uPlane.bytesPerRow + (x ~/ 2);

        final int yValue = yPlane.bytes[yIndex];
        final int uValue = uPlane.bytes[uvIndex];
        final int vValue = vPlane.bytes[uvIndex];

        final int r = (yValue + 1.402 * (vValue - 128)).clamp(0, 255).toInt();
        final int g =
            (yValue - 0.344136 * (uValue - 128) - 0.714136 * (vValue - 128))
                .clamp(0, 255)
                .toInt();
        final int b = (yValue + 1.772 * (uValue - 128)).clamp(0, 255).toInt();

        image.setPixel(x, y, img.ColorRgb8(r, g, b));
      }
    }

    return image;
  }

  Future<List<double>> detectFace(img.Image image) async {
    await _ensureDetectionInterpreter();

    if (!_detectionAvailable || _detectionInterpreter == null) {
      return _defaultBoundingBox();
    }

    try {
      final inputTensor = _detectionInterpreter!.getInputTensor(0);
      final input = _preprocessImageForTensor(
        image,
        inputTensor.shape,
        inputTensor.type,
      );

      final outputTensors = _detectionInterpreter!.getOutputTensors();
      if (outputTensors.isEmpty) {
        return _defaultBoundingBox();
      }

      final outputs = <int, Object>{};
      for (var i = 0; i < outputTensors.length; i++) {
        outputs[i] = _createTensorBuffer(
          outputTensors[i].shape,
          outputTensors[i].type,
        );
      }

      _detectionInterpreter!.runForMultipleInputs([input], outputs);
      return _extractBoundingBoxFromDetectionOutputs(outputTensors, outputs);
    } catch (e, stackTrace) {
      _detectionAvailable = false;
      debugPrint('Face detection fallback: $e');
      debugPrintStack(stackTrace: stackTrace);
      return _defaultBoundingBox();
    }
  }

  Future<List<double>> recognizeFace(img.Image faceImage) async {
    await _ensureRecognitionInterpreter();
    if (!_recognitionAvailable || _recognitionInterpreter == null) {
      return _extractFallbackEmbedding(faceImage);
    }

    final inputTensor = _recognitionInterpreter!.getInputTensor(0);
    try {
      final input = _preprocessImageForTensor(
        faceImage,
        inputTensor.shape,
        inputTensor.type,
      );

      final outputTensors = _recognitionInterpreter!.getOutputTensors();
      if (outputTensors.isEmpty) {
        throw StateError('The face recognition model has no output tensors.');
      }

      final outputs = <int, Object>{};
      for (var i = 0; i < outputTensors.length; i++) {
        outputs[i] = _createTensorBuffer(
          outputTensors[i].shape,
          outputTensors[i].type,
        );
      }
      _recognitionInterpreter!.runForMultipleInputs([input], outputs);

      final embedding = _flattenNumericTensor(outputs[0]!);
      if (embedding.isEmpty) {
        throw StateError(
          'The face recognition model returned an empty embedding.',
        );
      }

      return _normalizeEmbedding(embedding);
    } catch (e, stackTrace) {
      _recognitionAvailable = false;
      debugPrint('Recognition fallback engine engaged: $e');
      debugPrintStack(stackTrace: stackTrace);
      return _extractFallbackEmbedding(faceImage);
    }
  }

  Future<List<List<double>>> processBaselinePhotos(List<File> photos) async {
    final embeddings = <List<double>>[];

    for (final photo in photos) {
      final image = img.decodeImage(await photo.readAsBytes());
      if (image == null) {
        throw StateError('Could not decode photo: ${photo.path}');
      }

      final bbox = await detectFace(image);
      final cropped = cropFace(image, bbox);
      final embedding = await recognizeFace(cropped);
      embeddings.add(embedding);
    }

    return embeddings;
  }

  Object _preprocessImageForTensor(
    img.Image image,
    List<int> shape,
    TensorType type,
  ) {
    final spec = _resolveInputSpec(shape);
    final resized = img.copyResize(
      image,
      width: spec.width,
      height: spec.height,
    );
    final useFloats = _isFloatTensor(type);

    if (spec.channelsFirst) {
      final channels = List.generate(spec.channels, (channel) {
        return List.generate(spec.height, (y) {
          return List.generate(spec.width, (x) {
            final pixel = resized.getPixel(x, y);
            return _channelValue(pixel, channel: channel, useFloats: useFloats);
          }, growable: false);
        }, growable: false);
      }, growable: false);

      return spec.batched ? [channels] : channels;
    }

    final pixels = List.generate(spec.height, (y) {
      return List.generate(spec.width, (x) {
        final pixel = resized.getPixel(x, y);
        return _pixelValues(
          pixel,
          channels: spec.channels,
          useFloats: useFloats,
        );
      }, growable: false);
    }, growable: false);

    return spec.batched ? [pixels] : pixels;
  }

  img.Image cropFace(img.Image image, List<double> bbox) {
    final safeBbox = _sanitizeBoundingBox(bbox) ?? _defaultBoundingBox();
    final x = (safeBbox[0] * image.width).clamp(0, image.width - 1).toInt();
    final y = (safeBbox[1] * image.height).clamp(0, image.height - 1).toInt();
    final w = (safeBbox[2] * image.width).clamp(1, image.width - x).toInt();
    final h = (safeBbox[3] * image.height).clamp(1, image.height - y).toInt();
    return img.copyCrop(image, x: x, y: y, width: w, height: h);
  }

  img.Image rotateImage(img.Image image, {required int rotationDegrees}) {
    final normalizedRotation = rotationDegrees % 360;
    if (normalizedRotation == 0) {
      return image;
    }

    return img.copyRotate(image, angle: normalizedRotation);
  }

  img.Image flipImageHorizontally(img.Image image) {
    return img.copyFlip(image, direction: img.FlipDirection.horizontal);
  }

  List<double> _extractBoundingBoxFromDetectionOutputs(
    List<Tensor> outputTensors,
    Map<int, Object> outputs,
  ) {
    if (outputTensors.isEmpty || outputs.isEmpty) {
      return _defaultBoundingBox();
    }

    if (outputTensors.length == 1) {
      return _extractBoundingBoxFromTensor(outputs[0]!);
    }

    int? regressionIndex;
    int? scoreIndex;
    for (var i = 0; i < outputTensors.length; i++) {
      final shape = outputTensors[i].shape;
      if (shape.isEmpty) {
        continue;
      }

      if (shape.last >= 4 && regressionIndex == null) {
        regressionIndex = i;
      } else if (shape.last == 1 && scoreIndex == null) {
        scoreIndex = i;
      }
    }

    if (regressionIndex == null) {
      return _defaultBoundingBox();
    }

    final vectors = _extractNumericVectors(outputs[regressionIndex]!);
    if (vectors.isEmpty) {
      return _defaultBoundingBox();
    }

    if (scoreIndex == null) {
      return _extractBestBoundingBoxCandidate(vectors);
    }

    final scores = _flattenNumericTensor(outputs[scoreIndex]!);
    if (scores.isEmpty) {
      return _extractBestBoundingBoxCandidate(vectors);
    }

    final count = min(vectors.length, scores.length);
    double bestScore = -double.infinity;
    List<double>? bestCandidate;

    for (var i = 0; i < count; i++) {
      if (scores[i] > bestScore) {
        bestScore = scores[i];
        bestCandidate = vectors[i];
      }
    }

    return _sanitizeBoundingBox(bestCandidate) ?? _defaultBoundingBox();
  }

  List<double> _extractBoundingBoxFromTensor(Object tensorData) {
    final vectors = _extractNumericVectors(tensorData);
    if (vectors.isEmpty) {
      return _defaultBoundingBox();
    }

    return _extractBestBoundingBoxCandidate(vectors);
  }

  List<double> _extractBestBoundingBoxCandidate(List<List<double>> vectors) {
    double bestScore = -double.infinity;
    List<double>? bestCandidate;

    for (final vector in vectors) {
      if (vector.length < 4) {
        continue;
      }

      final score = vector.length > 4 ? vector.last : 1.0;
      if (score > bestScore) {
        bestScore = score;
        bestCandidate = vector;
      }
    }

    return _sanitizeBoundingBox(bestCandidate) ?? _defaultBoundingBox();
  }

  List<List<double>> _extractNumericVectors(Object data) {
    if (data is! List) {
      return const [];
    }

    if (data.isEmpty) {
      return const [];
    }

    if (data.first is num) {
      return [
        data
            .whereType<num>()
            .map((value) => value.toDouble())
            .toList(growable: false),
      ];
    }

    final vectors = <List<double>>[];
    for (final item in data) {
      vectors.addAll(_extractNumericVectors(item));
    }
    return vectors;
  }

  List<double> _flattenNumericTensor(Object data) {
    final values = <double>[];

    void visit(Object element) {
      if (element is List) {
        for (final item in element) {
          visit(item);
        }
      } else if (element is num) {
        values.add(element.toDouble());
      }
    }

    visit(data);
    return values;
  }

  List<double>? _sanitizeBoundingBox(List<double>? bbox) {
    if (bbox == null || bbox.length < 4) {
      return null;
    }

    final x = bbox[0];
    final y = bbox[1];
    final w = bbox[2];
    final h = bbox[3];

    final values = [x, y, w, h];
    if (values.any((value) => value.isNaN || value.isInfinite)) {
      return null;
    }

    if (x < 0 || y < 0 || w <= 0 || h <= 0) {
      return null;
    }

    if (x > 1 || y > 1 || w > 1 || h > 1) {
      return null;
    }

    final clampedWidth = min(w, 1.0 - x);
    final clampedHeight = min(h, 1.0 - y);
    if (clampedWidth <= 0 || clampedHeight <= 0) {
      return null;
    }

    return [x, y, clampedWidth, clampedHeight];
  }

  List<double> _defaultBoundingBox() => const [0.2, 0.12, 0.6, 0.76];

  List<double> _extractFallbackEmbedding(img.Image image) {
    final focusCrop = _centerSquareCrop(image);
    final resized = img.copyResize(
      focusCrop,
      width: 16,
      height: 16,
      interpolation: img.Interpolation.average,
    );

    final grayscale = <double>[];
    final rowMeans = List<double>.filled(16, 0);
    final columnMeans = List<double>.filled(16, 0);

    for (var y = 0; y < resized.height; y++) {
      for (var x = 0; x < resized.width; x++) {
        final pixel = resized.getPixel(x, y);
        final luminance =
            ((0.299 * pixel.r) + (0.587 * pixel.g) + (0.114 * pixel.b)) / 255;
        grayscale.add(luminance);
        rowMeans[y] += luminance;
        columnMeans[x] += luminance;
      }
    }

    for (var i = 0; i < rowMeans.length; i++) {
      rowMeans[i] /= resized.width;
      columnMeans[i] /= resized.height;
    }

    final histogram = List<double>.filled(16, 0);
    for (final value in grayscale) {
      final bucket = (value * 15).clamp(0, 15).floor();
      histogram[bucket] += 1;
    }
    for (var i = 0; i < histogram.length; i++) {
      histogram[i] /= grayscale.length;
    }

    final featureVector = <double>[
      ...grayscale,
      ...rowMeans,
      ...columnMeans,
      ...histogram,
    ];
    final mean =
        featureVector.reduce((sum, value) => sum + value) /
        featureVector.length;
    final variance = featureVector.fold<double>(
      0,
      (sum, value) => sum + pow(value - mean, 2).toDouble(),
    );
    final stdDev = sqrt(variance / featureVector.length).clamp(0.0001, 10.0);

    final normalized = featureVector
        .map((value) => (value - mean) / stdDev)
        .toList(growable: false);
    return _normalizeEmbedding(normalized);
  }

  img.Image _centerSquareCrop(img.Image image) {
    final size = min(image.width, image.height);
    final x = ((image.width - size) / 2).round();
    final y = ((image.height - size) / 2).round();
    return img.copyCrop(image, x: x, y: y, width: size, height: size);
  }

  List<double> _normalizeEmbedding(List<double> embedding) {
    final squaredSum = embedding.fold<double>(
      0,
      (sum, value) => sum + (value * value),
    );
    if (squaredSum == 0) {
      return embedding;
    }

    final magnitude = sqrt(squaredSum);
    return embedding.map((value) => value / magnitude).toList(growable: false);
  }

  ({int height, int width, int channels, bool batched, bool channelsFirst})
  _resolveInputSpec(List<int> shape) {
    if (shape.length == 4) {
      if (shape[3] == 1 || shape[3] == 3) {
        return (
          height: shape[1],
          width: shape[2],
          channels: shape[3],
          batched: true,
          channelsFirst: false,
        );
      }

      if (shape[1] == 1 || shape[1] == 3) {
        return (
          height: shape[2],
          width: shape[3],
          channels: shape[1],
          batched: true,
          channelsFirst: true,
        );
      }
    }

    if (shape.length == 3) {
      if (shape[2] == 1 || shape[2] == 3) {
        return (
          height: shape[0],
          width: shape[1],
          channels: shape[2],
          batched: false,
          channelsFirst: false,
        );
      }

      if (shape[0] == 1 || shape[0] == 3) {
        return (
          height: shape[1],
          width: shape[2],
          channels: shape[0],
          batched: false,
          channelsFirst: true,
        );
      }
    }

    throw StateError('Unsupported model input shape: $shape');
  }

  Object _createTensorBuffer(List<int> shape, TensorType type) {
    final zero = _isFloatTensor(type) ? 0.0 : 0;
    return _createNestedBuffer(shape, zero);
  }

  Object _createNestedBuffer(List<int> shape, num zero) {
    if (shape.isEmpty) {
      return zero;
    }

    return List.generate(
      shape.first,
      (_) => _createNestedBuffer(shape.sublist(1), zero),
      growable: false,
    );
  }

  bool _isFloatTensor(TensorType type) =>
      type == TensorType.float16 ||
      type == TensorType.float32 ||
      type == TensorType.float64;

  num _channelValue(
    img.Pixel pixel, {
    required int channel,
    required bool useFloats,
  }) {
    final values = [pixel.r, pixel.g, pixel.b];
    final safeChannel = channel.clamp(0, values.length - 1);
    final value = values[safeChannel];
    return useFloats ? value / 255.0 : value;
  }

  List<num> _pixelValues(
    img.Pixel pixel, {
    required int channels,
    required bool useFloats,
  }) {
    if (channels <= 1) {
      final grayscale = (pixel.r + pixel.g + pixel.b) / 3;
      return [useFloats ? grayscale / 255.0 : grayscale.round()];
    }

    return List.generate(
      channels,
      (channel) => _channelValue(pixel, channel: channel, useFloats: useFloats),
      growable: false,
    );
  }

  double _calculateDistance(List<double> emb1, List<double> emb2) {
    final length = min(emb1.length, emb2.length);
    if (length == 0) {
      return double.infinity;
    }

    double sum = 0;
    for (int i = 0; i < length; i++) {
      sum += pow(emb1[i] - emb2[i], 2).toDouble();
    }
    return sqrt(sum);
  }

  Future<String?> recognizeStudent(
    List<Student> students,
    List<double> liveEmbedding, {
    double threshold = 0.8,
    Iterable<List<double>> alternateEmbeddings = const [],
  }) async {
    double minDistance = double.infinity;
    String? bestStudentId;
    final liveCandidates = <List<double>>[liveEmbedding, ...alternateEmbeddings];

    for (final student in students) {
      if (student.embeddings.isEmpty) {
        continue;
      }

      final averageEmbedding = _averageEmbeddings(student.embeddings);
      double studentBestDistance = double.infinity;

      for (final candidate in liveCandidates) {
        for (final storedEmbedding in student.embeddings) {
          final distance = _calculateDistance(storedEmbedding, candidate);
          if (distance < studentBestDistance) {
            studentBestDistance = distance;
          }
        }

        final averageDistance = _calculateDistance(averageEmbedding, candidate);
        if (averageDistance < studentBestDistance) {
          studentBestDistance = averageDistance;
        }
      }

      if (studentBestDistance < minDistance) {
        minDistance = studentBestDistance;
        bestStudentId = student.id;
      }
    }

    if (minDistance < threshold) {
      return bestStudentId;
    }
    return null;
  }

  List<double> _averageEmbeddings(List<List<double>> embeddings) {
    if (embeddings.isEmpty) {
      return const [];
    }

    final embeddingLength = embeddings
        .map((embedding) => embedding.length)
        .reduce(min);
    if (embeddingLength == 0) {
      return const [];
    }

    final averageEmbedding = List<double>.filled(embeddingLength, 0.0);
    for (final embedding in embeddings) {
      for (var i = 0; i < embeddingLength; i++) {
        averageEmbedding[i] += embedding[i];
      }
    }

    for (var i = 0; i < averageEmbedding.length; i++) {
      averageEmbedding[i] /= embeddings.length;
    }

    return _normalizeEmbedding(averageEmbedding);
  }

  void dispose() {
    _detectionInterpreter?.close();
    _recognitionInterpreter?.close();
  }
}
