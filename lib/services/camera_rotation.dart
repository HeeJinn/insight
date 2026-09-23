import 'package:camera/camera.dart';
import 'package:flutter/services.dart';

/// Degrees to rotate a raw [CameraImage] from [controller] so the face is
/// upright before detection.
int cameraRotationCompensation(CameraController controller) {
  final deviceRotation = switch (controller.value.deviceOrientation) {
    DeviceOrientation.portraitUp => 0,
    DeviceOrientation.landscapeLeft => 90,
    DeviceOrientation.portraitDown => 180,
    DeviceOrientation.landscapeRight => 270,
  };

  final sensorOrientation = controller.description.sensorOrientation;
  if (controller.description.lensDirection == CameraLensDirection.front) {
    return (sensorOrientation + deviceRotation) % 360;
  }

  return (sensorOrientation - deviceRotation + 360) % 360;
}
