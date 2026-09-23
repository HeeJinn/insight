import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../models/student.dart';
import 'face_pose.dart';

export 'face_pose.dart';

/// Output of one pass through the face pipeline.
class FaceScanResult {
  const FaceScanResult({
    required this.embedding,
    required this.mirroredEmbedding,
    required this.box,
    required this.detectionScore,
    required this.processingMs,
  });

  /// L2-normalized MobileFaceNet embedding of the aligned face.
  final List<double> embedding;

  /// Embedding of the horizontally mirrored aligned face.
  final List<double> mirroredEmbedding;

  /// Face box `[x, y, width, height]`, normalized (0..1) to the processed
  /// (already rotated) image.
  final List<double> box;

  /// BlazeFace confidence (0..1) of the selected face.
  final double detectionScore;

  /// Time spent inside the worker isolate (decode/convert, detect, align,
  /// embed), in milliseconds.
  final int processingMs;
}

/// On-device face pipeline: BlazeFace detection, landmark alignment and
/// MobileFaceNet embeddings.
///
/// All heavy work (camera frame conversion, image decoding, both TFLite
/// models) runs in a dedicated background isolate so the UI thread never
/// blocks on inference. Only the cheap distance comparison in
/// [recognizeStudent] runs on the calling isolate.
class FaceProcessor {
  static const String detectionModelPath =
      'assets/models/face_detection_front.tflite';
  static const String recognitionModelPath =
      'assets/models/mobile_face_net.tflite';

  /// Length of a MobileFaceNet embedding. Stored embeddings of any other
  /// length come from an older pipeline and are ignored during matching.
  static const int embeddingLength = 192;

  /// Default Euclidean distance threshold for a match between two
  /// L2-normalized embeddings.
  static const double defaultThreshold = 1.0;

  /// The best match must beat the runner-up by at least this distance.
  static const double ambiguityMargin = 0.12;

  static bool isCompatibleEmbedding(List<double> embedding) =>
      embedding.length == embeddingLength;

  /// True when at least one of the student's baselines was produced by the
  /// current pipeline.
  static bool hasCompatibleEmbeddings(Student student) =>
      student.embeddings.any(isCompatibleEmbedding);

  Future<_FaceWorker>? _workerFuture;
  bool _disposed = false;

  /// Starts the worker isolate and loads both models. Optional: every
  /// processing call loads the models on first use.
  Future<void> loadModels() async {
    await _ensureWorker();
  }

  Future<_FaceWorker> _ensureWorker() {
    if (_disposed) {
      return Future.error(StateError('FaceProcessor has been disposed.'));
    }
    final existing = _workerFuture;
    if (existing != null) {
      return existing;
    }
    final future = _FaceWorker.spawn().then((worker) {
      if (_disposed) {
        worker.close();
        throw StateError('FaceProcessor has been disposed.');
      }
      return worker;
    });
    _workerFuture = future;
    // Allow a later call to retry if the models failed to load.
    future.then<void>(
      (_) {},
      onError: (Object _) {
        if (identical(_workerFuture, future)) {
          _workerFuture = null;
        }
      },
    );
    return future;
  }

  /// Processes a live camera frame. [rotationDegrees] rotates the frame
  /// upright before detection. Returns null when no face is found.
  Future<FaceScanResult?> processCameraImage(
    CameraImage image, {
    int rotationDegrees = 0,
  }) async {
    // Copy the frame before any await so the camera plugin can reuse its
    // buffers.
    final frame = _CameraFrame.fromCameraImage(image, rotationDegrees);
    final worker = await _ensureWorker();
    return worker.request<FaceScanResult>(frame);
  }

  /// Processes an encoded image (JPEG/PNG bytes), e.g. a kiosk snapshot or
  /// a registration photo. Returns null when no face is found.
  Future<FaceScanResult?> processEncodedImage(Uint8List bytes) async {
    final worker = await _ensureWorker();
    return worker.request<FaceScanResult>(_EncodedImage(bytes));
  }

  /// Detects the face in a live camera frame and estimates its pose,
  /// without computing an embedding. Returns null when no face is found.
  Future<FaceObservation?> detectCameraImage(
    CameraImage image, {
    int rotationDegrees = 0,
  }) async {
    final frame = _CameraFrame.fromCameraImage(image, rotationDegrees);
    final worker = await _ensureWorker();
    return worker.request<FaceObservation>(_DetectOnly(frame));
  }

  /// Detects the face in an encoded image and estimates its pose, without
  /// computing an embedding. Returns null when no face is found.
  Future<FaceObservation?> detectEncodedImage(Uint8List bytes) async {
    final worker = await _ensureWorker();
    return worker.request<FaceObservation>(_DetectOnly(_EncodedImage(bytes)));
  }

  /// Produces one embedding per baseline photo. Throws when a photo cannot
  /// be decoded or contains no detectable face.
  Future<List<List<double>>> processBaselinePhotos(List<File> photos) async {
    final embeddings = <List<double>>[];
    for (var i = 0; i < photos.length; i++) {
      final result = await processEncodedImage(await photos[i].readAsBytes());
      if (result == null) {
        throw StateError(
          'No face was detected in photo ${i + 1}. Retake it with the whole '
          'face visible and evenly lit.',
        );
      }
      embeddings.add(result.embedding);
    }
    return embeddings;
  }

  /// Returns the ID of the registered student whose stored embeddings are
  /// closest to [liveEmbedding], or null when no student is close enough.
  ///
  /// A student's score is the smallest Euclidean distance between any live
  /// candidate ([liveEmbedding] and [alternateEmbeddings]) and any of the
  /// student's baselines or their average. The best student is accepted
  /// only when its score is below [threshold] and at least
  /// [ambiguityMargin] lower than the runner-up.
  Future<String?> recognizeStudent(
    List<Student> students,
    List<double> liveEmbedding, {
    double threshold = defaultThreshold,
    Iterable<List<double>> alternateEmbeddings = const [],
  }) async {
    final liveCandidates = <List<double>>[
      liveEmbedding,
      ...alternateEmbeddings,
    ].where((e) => e.length == liveEmbedding.length).toList();
    final distancesByStudent = <String, double>{};

    for (final student in students) {
      final baselines = student.embeddings
          .where((e) => e.length == liveEmbedding.length)
          .toList(growable: false);
      if (baselines.isEmpty) {
        continue;
      }

      final references = <List<double>>[
        ...baselines,
        if (baselines.length > 1) _averageEmbeddings(baselines),
      ];

      var studentBest = double.infinity;
      for (final candidate in liveCandidates) {
        for (final reference in references) {
          final distance = _euclidean(reference, candidate);
          if (distance < studentBest) {
            studentBest = distance;
          }
        }
      }
      distancesByStudent[student.id] = studentBest;
    }

    if (distancesByStudent.isEmpty) {
      return null;
    }

    final ranked = distancesByStudent.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final best = ranked.first;
    final runnerUp = ranked.length > 1 ? ranked[1].value : double.infinity;

    final passesThreshold = best.value < threshold;
    final clearlySeparated =
        runnerUp.isInfinite || (runnerUp - best.value) >= ambiguityMargin;
    return passesThreshold && clearlySeparated ? best.key : null;
  }

  static double _euclidean(List<double> a, List<double> b) {
    var sum = 0.0;
    for (var i = 0; i < a.length; i++) {
      final d = a[i] - b[i];
      sum += d * d;
    }
    return math.sqrt(sum);
  }

  static List<double> _averageEmbeddings(List<List<double>> embeddings) {
    final length = embeddings.first.length;
    final average = List<double>.filled(length, 0.0);
    for (final embedding in embeddings) {
      for (var i = 0; i < length; i++) {
        average[i] += embedding[i];
      }
    }
    return _l2Normalize(average);
  }

  void dispose() {
    _disposed = true;
    final future = _workerFuture;
    _workerFuture = null;
    future?.then((worker) => worker.close(), onError: (Object _) {});
  }
}

List<double> _l2Normalize(List<double> v) {
  var sum = 0.0;
  for (final x in v) {
    sum += x * x;
  }
  if (sum == 0) {
    return List<double>.of(v, growable: false);
  }
  final norm = math.sqrt(sum);
  return List<double>.generate(v.length, (i) => v[i] / norm, growable: false);
}

// ---------------------------------------------------------------------------
// Worker isolate plumbing
// ---------------------------------------------------------------------------

class _WorkerInit {
  _WorkerInit(this.replyPort, this.detectionModel, this.recognitionModel);
  final SendPort replyPort;
  final TransferableTypedData detectionModel;
  final TransferableTypedData recognitionModel;
}

class _WorkerRequest {
  _WorkerRequest(this.id, this.payload);
  final int id;
  final Object payload;
}

class _WorkerResponse {
  _WorkerResponse(this.id, this.result, this.error);
  final int id;
  final Object? result;
  final String? error;
}

class _WorkerInitError {
  _WorkerInitError(this.message);
  final String message;
}

class _WorkerShutdown {
  const _WorkerShutdown();
}

class _EncodedImage {
  _EncodedImage(Uint8List bytes)
    : data = TransferableTypedData.fromList([bytes]);
  final TransferableTypedData data;
}

/// Wraps a [_CameraFrame] or [_EncodedImage] to request detection and pose
/// only, skipping alignment and embedding.
class _DetectOnly {
  _DetectOnly(this.image);
  final Object image;
}

/// A camera frame copied out of the plugin's buffers so it can be sent to
/// the worker isolate.
class _CameraFrame {
  _CameraFrame({
    required this.width,
    required this.height,
    required this.isBgra,
    required this.planes,
    required this.rowStrides,
    required this.pixelStrides,
    required this.rotationDegrees,
  });

  factory _CameraFrame.fromCameraImage(CameraImage image, int rotation) {
    return _CameraFrame(
      width: image.width,
      height: image.height,
      isBgra: image.format.group == ImageFormatGroup.bgra8888,
      planes: [
        for (final plane in image.planes)
          TransferableTypedData.fromList([plane.bytes]),
      ],
      rowStrides: [for (final plane in image.planes) plane.bytesPerRow],
      pixelStrides: [for (final plane in image.planes) plane.bytesPerPixel],
      rotationDegrees: rotation,
    );
  }

  final int width;
  final int height;
  final bool isBgra;
  final List<TransferableTypedData> planes;
  final List<int> rowStrides;
  final List<int?> pixelStrides;
  final int rotationDegrees;
}

class _FaceWorker {
  _FaceWorker._(this._isolate, this._receivePort);

  final Isolate _isolate;
  final ReceivePort _receivePort;
  SendPort? _sendPort;
  final Map<int, Completer<Object?>> _pending = {};
  int _nextId = 0;
  bool _closed = false;

  static Future<_FaceWorker> spawn() async {
    final detection = await rootBundle.load(FaceProcessor.detectionModelPath);
    final recognition = await rootBundle.load(
      FaceProcessor.recognitionModelPath,
    );

    final receivePort = ReceivePort();
    final ready = Completer<SendPort>();
    _FaceWorker? worker;

    receivePort.listen((message) {
      if (message is SendPort) {
        if (!ready.isCompleted) ready.complete(message);
      } else if (message is _WorkerInitError) {
        if (!ready.isCompleted) {
          ready.completeError(StateError(message.message));
        }
      } else if (message is _WorkerResponse) {
        worker?._handleResponse(message);
      }
    });

    Isolate isolate;
    try {
      isolate = await Isolate.spawn(
        _faceWorkerMain,
        _WorkerInit(
          receivePort.sendPort,
          TransferableTypedData.fromList([
            detection.buffer.asUint8List(
              detection.offsetInBytes,
              detection.lengthInBytes,
            ),
          ]),
          TransferableTypedData.fromList([
            recognition.buffer.asUint8List(
              recognition.offsetInBytes,
              recognition.lengthInBytes,
            ),
          ]),
        ),
        debugName: 'face-pipeline',
      );
    } catch (_) {
      receivePort.close();
      rethrow;
    }

    try {
      final sendPort = await ready.future.timeout(const Duration(seconds: 30));
      worker = _FaceWorker._(isolate, receivePort).._sendPort = sendPort;
      return worker;
    } catch (e) {
      isolate.kill(priority: Isolate.immediate);
      receivePort.close();
      rethrow;
    }
  }

  Future<T?> request<T extends Object>(Object payload) async {
    final sendPort = _sendPort;
    if (_closed || sendPort == null) {
      throw StateError('Face pipeline is not running.');
    }
    final id = _nextId++;
    final completer = Completer<Object?>();
    _pending[id] = completer;
    sendPort.send(_WorkerRequest(id, payload));
    return await completer.future as T?;
  }

  void _handleResponse(_WorkerResponse response) {
    final completer = _pending.remove(response.id);
    if (completer == null) return;
    if (response.error != null) {
      completer.completeError(StateError(response.error!));
    } else {
      completer.complete(response.result);
    }
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _sendPort?.send(const _WorkerShutdown());
    for (final completer in _pending.values) {
      completer.completeError(StateError('Face pipeline was closed.'));
    }
    _pending.clear();
    _receivePort.close();
    // Give the worker a moment to release the native interpreters, then
    // make sure the isolate is gone.
    final isolate = _isolate;
    Future<void>.delayed(const Duration(seconds: 2), () {
      isolate.kill(priority: Isolate.immediate);
    });
  }
}

Future<void> _faceWorkerMain(_WorkerInit init) async {
  final _FacePipeline pipeline;
  try {
    pipeline = _FacePipeline(
      Interpreter.fromBuffer(init.detectionModel.materialize().asUint8List()),
      Interpreter.fromBuffer(init.recognitionModel.materialize().asUint8List()),
    );
  } catch (e) {
    init.replyPort.send(_WorkerInitError('Could not load face models: $e'));
    return;
  }

  final port = ReceivePort();
  init.replyPort.send(port.sendPort);

  await for (final message in port) {
    if (message is _WorkerShutdown) {
      pipeline.close();
      port.close();
      break;
    }
    if (message is _WorkerRequest) {
      try {
        final result = pipeline.process(message.payload);
        init.replyPort.send(_WorkerResponse(message.id, result, null));
      } catch (e) {
        init.replyPort.send(_WorkerResponse(message.id, null, '$e'));
      }
    }
  }
}

// ---------------------------------------------------------------------------
// The pipeline itself (runs inside the worker isolate)
// ---------------------------------------------------------------------------

class _Detection {
  _Detection(this.box, this.keypoints, this.score);

  /// `[x, y, width, height]` normalized to the image.
  final List<double> box;

  /// Six landmarks, normalized: right eye, left eye, nose tip, mouth
  /// centre, right ear, left ear (subject's left/right).
  final List<math.Point<double>> keypoints;
  final double score;
}

class _FacePipeline {
  _FacePipeline(this._detector, this._recognizer) {
    final detInput = _detector.getInputTensor(0).shape; // [1, 128, 128, 3]
    _detSize = detInput[1];

    final outputs = _detector.getOutputTensors();
    for (var i = 0; i < outputs.length; i++) {
      final shape = outputs[i].shape;
      if (shape.last == 16) _regressorIndex = i;
      if (shape.last == 1) _scoreIndex = i;
    }
    if (_regressorIndex < 0 || _scoreIndex < 0) {
      throw StateError('Unexpected face detection model outputs.');
    }
    _anchors = _buildAnchors(_detSize);
    final anchorCount = outputs[_regressorIndex].shape[1];
    if (_anchors.length != anchorCount) {
      throw StateError(
        'Anchor mismatch: model has $anchorCount, generated ${_anchors.length}.',
      );
    }

    final recInput = _recognizer.getInputTensor(0).shape; // [2, 112, 112, 3]
    _recBatch = recInput[0];
    _recSize = recInput[1];
  }

  static const double _minDetectionScore = 0.5;

  /// Landmark positions (right eye, left eye, nose tip, mouth centre) of
  /// the standard 112x112 ArcFace/InsightFace alignment template.
  static const List<List<double>> _template = [
    [38.2946, 51.6963],
    [73.5318, 51.5014],
    [56.0252, 71.7366],
    [56.1396, 92.2848],
  ];

  final Interpreter _detector;
  final Interpreter _recognizer;
  late final int _detSize;
  late final List<math.Point<double>> _anchors;
  int _regressorIndex = -1;
  int _scoreIndex = -1;
  late final int _recBatch;
  late final int _recSize;

  Object? process(Object payload) {
    if (payload is _DetectOnly) {
      return _observe(_toImage(payload.image));
    }

    final stopwatch = Stopwatch()..start();
    final image = _toImage(payload);
    final detection = _detect(image);
    if (detection == null) {
      return null;
    }

    final aligned = _align(image, detection.keypoints);
    final embeddings = _embed(aligned);
    stopwatch.stop();
    return FaceScanResult(
      embedding: embeddings.first,
      mirroredEmbedding: embeddings.last,
      box: detection.box,
      detectionScore: detection.score,
      processingMs: stopwatch.elapsedMilliseconds,
    );
  }

  img.Image _toImage(Object payload) {
    if (payload is _CameraFrame) {
      final converted = _convertCameraFrame(payload);
      final rotation = payload.rotationDegrees % 360;
      return rotation == 0
          ? converted
          : img.copyRotate(converted, angle: rotation);
    }
    if (payload is _EncodedImage) {
      final decoded = img.decodeImage(payload.data.materialize().asUint8List());
      if (decoded == null) {
        throw StateError('The image could not be decoded.');
      }
      return img.bakeOrientation(decoded);
    }
    throw ArgumentError('Unsupported payload ${payload.runtimeType}');
  }

  FaceObservation? _observe(img.Image image) {
    final detection = _detect(image);
    if (detection == null) {
      return null;
    }
    // Pose needs x and y on the same scale, so work in pixels.
    final w = image.width.toDouble();
    final h = image.height.toDouble();
    math.Point<double> px(int k) =>
        math.Point(detection.keypoints[k].x * w, detection.keypoints[k].y * h);
    final pose = FacePose.fromLandmarks(px(0), px(1), px(2), px(3));
    if (pose == null) {
      return null;
    }
    return FaceObservation(
      box: detection.box,
      score: detection.score,
      pose: pose,
    );
  }

  // -- Detection ------------------------------------------------------------

  /// SSD anchors of the BlazeFace short-range model: 2 anchors per cell on
  /// the stride-8 grid and 6 per cell on the stride-16 grid (896 total for a
  /// 128x128 input). Anchor width/height are fixed at 1.
  static List<math.Point<double>> _buildAnchors(int inputSize) {
    const strides = [8, 16, 16, 16];
    final anchors = <math.Point<double>>[];
    var layer = 0;
    while (layer < strides.length) {
      final stride = strides[layer];
      var perCell = 0;
      var last = layer;
      while (last < strides.length && strides[last] == stride) {
        perCell += 2;
        last++;
      }
      final grid = (inputSize / stride).ceil();
      for (var y = 0; y < grid; y++) {
        for (var x = 0; x < grid; x++) {
          for (var n = 0; n < perCell; n++) {
            anchors.add(math.Point((x + 0.5) / grid, (y + 0.5) / grid));
          }
        }
      }
      layer = last;
    }
    return anchors;
  }

  _Detection? _detect(img.Image image) {
    final size = _detSize;
    final resized = img.copyResize(
      image,
      width: size,
      height: size,
      interpolation: img.Interpolation.linear,
    );
    final input = Float32List(size * size * 3);
    var i = 0;
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        final p = resized.getPixel(x, y);
        input[i++] = p.r / 127.5 - 1.0;
        input[i++] = p.g / 127.5 - 1.0;
        input[i++] = p.b / 127.5 - 1.0;
      }
    }

    _detector.runInference([input.buffer.asUint8List()]);
    final regressors = _readFloats(_detector.getOutputTensor(_regressorIndex));
    final scores = _readFloats(_detector.getOutputTensor(_scoreIndex));

    var best = 0;
    for (var k = 1; k < scores.length; k++) {
      if (scores[k] > scores[best]) best = k;
    }
    final score = 1.0 / (1.0 + math.exp(-scores[best].clamp(-100.0, 100.0)));
    if (score < _minDetectionScore) {
      return null;
    }

    final anchor = _anchors[best];
    final r = best * 16;
    final cx = regressors[r] / size + anchor.x;
    final cy = regressors[r + 1] / size + anchor.y;
    final w = regressors[r + 2] / size;
    final h = regressors[r + 3] / size;
    final keypoints = <math.Point<double>>[
      for (var k = 0; k < 6; k++)
        math.Point(
          regressors[r + 4 + 2 * k] / size + anchor.x,
          regressors[r + 5 + 2 * k] / size + anchor.y,
        ),
    ];

    final left = (cx - w / 2).clamp(0.0, 1.0);
    final top = (cy - h / 2).clamp(0.0, 1.0);
    final right = (cx + w / 2).clamp(0.0, 1.0);
    final bottom = (cy + h / 2).clamp(0.0, 1.0);
    return _Detection(
      [left, top, right - left, bottom - top],
      keypoints,
      score,
    );
  }

  // -- Alignment ------------------------------------------------------------

  /// Warps the face to the 112x112 template with a similarity transform
  /// (rotation, uniform scale, translation) fitted to four landmarks.
  img.Image _align(img.Image image, List<math.Point<double>> keypoints) {
    final w = image.width.toDouble();
    final h = image.height.toDouble();
    final src = [
      for (var k = 0; k < 4; k++) [keypoints[k].x * w, keypoints[k].y * h],
    ];
    final scale = _recSize / 112.0;
    final dst = [
      for (final p in _template) [p[0] * scale, p[1] * scale],
    ];

    // Least-squares similarity: dst = [a -b; b a] * src + t
    var smx = 0.0, smy = 0.0, dmx = 0.0, dmy = 0.0;
    for (var k = 0; k < 4; k++) {
      smx += src[k][0];
      smy += src[k][1];
      dmx += dst[k][0];
      dmy += dst[k][1];
    }
    smx /= 4;
    smy /= 4;
    dmx /= 4;
    dmy /= 4;
    var num1 = 0.0, num2 = 0.0, den = 0.0;
    for (var k = 0; k < 4; k++) {
      final sx = src[k][0] - smx, sy = src[k][1] - smy;
      final dx = dst[k][0] - dmx, dy = dst[k][1] - dmy;
      num1 += sx * dx + sy * dy;
      num2 += sx * dy - sy * dx;
      den += sx * sx + sy * sy;
    }
    if (den == 0) {
      throw StateError('Degenerate face landmarks.');
    }
    final a = num1 / den;
    final b = num2 / den;
    final tx = dmx - (a * smx - b * smy);
    final ty = dmy - (b * smx + a * smy);

    // Inverse map: src = M^-1 (dst - t)
    final det = a * a + b * b;
    final ia = a / det;
    final ib = b / det;

    final out = img.Image(width: _recSize, height: _recSize);
    final maxX = image.width - 1;
    final maxY = image.height - 1;
    for (var v = 0; v < _recSize; v++) {
      for (var u = 0; u < _recSize; u++) {
        final px = u - tx;
        final py = v - ty;
        final sx = ia * px + ib * py;
        final sy = -ib * px + ia * py;
        if (sx < 0 || sy < 0 || sx > maxX || sy > maxY) {
          out.setPixelRgb(u, v, 0, 0, 0);
          continue;
        }
        final x0 = sx.floor(), y0 = sy.floor();
        final x1 = math.min(x0 + 1, maxX), y1 = math.min(y0 + 1, maxY);
        final fx = sx - x0, fy = sy - y0;
        final p00 = image.getPixel(x0, y0);
        final p10 = image.getPixel(x1, y0);
        final p01 = image.getPixel(x0, y1);
        final p11 = image.getPixel(x1, y1);
        final w00 = (1 - fx) * (1 - fy);
        final w10 = fx * (1 - fy);
        final w01 = (1 - fx) * fy;
        final w11 = fx * fy;
        out.setPixelRgb(
          u,
          v,
          (p00.r * w00 + p10.r * w10 + p01.r * w01 + p11.r * w11).round(),
          (p00.g * w00 + p10.g * w10 + p01.g * w01 + p11.g * w11).round(),
          (p00.b * w00 + p10.b * w10 + p01.b * w01 + p11.b * w11).round(),
        );
      }
    }
    return out;
  }

  // -- Recognition ----------------------------------------------------------

  /// Runs MobileFaceNet on the aligned face and (when the model's batch
  /// allows) its mirror image in a single call. The bundled model has a
  /// fixed batch size of 2, so the input must always fill both slots.
  List<List<double>> _embed(img.Image face) {
    final size = _recSize;
    final perImage = size * size * 3;
    final input = Float32List(perImage * _recBatch);
    for (var slot = 0; slot < _recBatch; slot++) {
      final mirror = slot.isOdd;
      var i = slot * perImage;
      for (var y = 0; y < size; y++) {
        for (var x = 0; x < size; x++) {
          final p = face.getPixel(mirror ? size - 1 - x : x, y);
          input[i++] = (p.r - 127.5) / 128.0;
          input[i++] = (p.g - 127.5) / 128.0;
          input[i++] = (p.b - 127.5) / 128.0;
        }
      }
    }

    _recognizer.runInference([input.buffer.asUint8List()]);
    final output = _readFloats(_recognizer.getOutputTensor(0));
    final length = output.length ~/ _recBatch;
    final original = _l2Normalize(output.sublist(0, length));
    final mirrored = _recBatch > 1
        ? _l2Normalize(output.sublist(length, 2 * length))
        : original;
    return [original, mirrored];
  }

  // -- Helpers --------------------------------------------------------------

  static List<double> _readFloats(Tensor tensor) {
    final bytes = Uint8List.fromList(tensor.data);
    return bytes.buffer.asFloat32List();
  }

  static img.Image _convertCameraFrame(_CameraFrame frame) {
    final width = frame.width;
    final height = frame.height;
    final image = img.Image(width: width, height: height);
    final planes = [
      for (final plane in frame.planes) plane.materialize().asUint8List(),
    ];

    // Single-plane frames (BGRA8888 on iOS/macOS/Windows, or RGBA).
    if (planes.length == 1) {
      final bytes = planes.first;
      final rowStride = frame.rowStrides.first;
      final pixelStride = frame.pixelStrides.first ?? 4;
      for (var y = 0; y < height; y++) {
        final rowOffset = y * rowStride;
        for (var x = 0; x < width; x++) {
          final index = rowOffset + x * pixelStride;
          if (index + 2 >= bytes.length) continue;
          if (frame.isBgra) {
            image.setPixelRgb(x, y, bytes[index + 2], bytes[index + 1],
                bytes[index]);
          } else {
            image.setPixelRgb(x, y, bytes[index], bytes[index + 1],
                bytes[index + 2]);
          }
        }
      }
      return image;
    }

    // Multi-plane YUV420 (Android).
    final yPlane = planes[0];
    final uPlane = planes[1];
    final vPlane = planes.length > 2 ? planes[2] : planes[1];
    final yRowStride = frame.rowStrides[0];
    final uRowStride = frame.rowStrides[1];
    final vRowStride = frame.rowStrides.length > 2
        ? frame.rowStrides[2]
        : frame.rowStrides[1];
    final uPixelStride = frame.pixelStrides[1] ?? 1;
    final vPixelStride = frame.pixelStrides.length > 2
        ? (frame.pixelStrides[2] ?? 1)
        : uPixelStride;

    for (var y = 0; y < height; y++) {
      final yOffset = y * yRowStride;
      final uvRow = y >> 1;
      final uRowOffset = uvRow * uRowStride;
      final vRowOffset = uvRow * vRowStride;
      for (var x = 0; x < width; x++) {
        final yIndex = yOffset + x;
        final uvCol = x >> 1;
        final uIndex = uRowOffset + uvCol * uPixelStride;
        final vIndex = vRowOffset + uvCol * vPixelStride;
        if (yIndex >= yPlane.length ||
            uIndex >= uPlane.length ||
            vIndex >= vPlane.length) {
          continue;
        }
        final yValue = yPlane[yIndex];
        final uValue = uPlane[uIndex] - 128;
        final vValue = vPlane[vIndex] - 128;
        final r = (yValue + 1.402 * vValue).round().clamp(0, 255);
        final g = (yValue - 0.344136 * uValue - 0.714136 * vValue)
            .round()
            .clamp(0, 255);
        final b = (yValue + 1.772 * uValue).round().clamp(0, 255);
        image.setPixelRgb(x, y, r, g, b);
      }
    }
    return image;
  }

  void close() {
    _detector.close();
    _recognizer.close();
  }
}
