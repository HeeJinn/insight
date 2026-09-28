import 'package:camera/camera.dart';

/// Whether [error] means the user (or the system) refused camera access.
///
/// camera_desktop (macOS) reports `permission_denied`; the Android and iOS
/// plugins report `CameraAccessDenied` and its variants.
bool isCameraPermissionError(Object? error) =>
    error is CameraException &&
    (error.code == 'permission_denied' ||
        error.code.startsWith('CameraAccessDenied'));
