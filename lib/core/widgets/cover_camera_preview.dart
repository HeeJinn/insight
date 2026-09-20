import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';

/// Renders a [CameraPreview] that fills its bounds without stretching.
///
/// [CameraPreview] wraps its texture in an [AspectRatio], which can only
/// honor the camera's aspect ratio when given loose constraints. Placed
/// directly inside a tightly-constrained box (e.g. a `Stack` with
/// `fit: StackFit.expand`), it gets forced to that box's exact size and the
/// image visibly squishes or stretches. This widget instead lets the
/// preview size itself correctly, then uniformly scales it up just enough
/// to cover the available space, clipping the overflow — the same
/// "cover" behavior as `BoxFit.cover`, without distorting the picture.
class CoverCameraPreview extends StatelessWidget {
  final CameraController controller;

  /// Painted directly over the camera texture, inside the same
  /// scale-to-cover transform — so painted coordinates line up with the
  /// displayed image without any extra crop/scale math of their own.
  final CustomPainter? foregroundPainter;

  const CoverCameraPreview({
    super.key,
    required this.controller,
    this.foregroundPainter,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final containerRatio = constraints.maxWidth / constraints.maxHeight;
          final previewRatio = controller.value.aspectRatio;

          var scale = containerRatio / previewRatio;
          if (scale < 1) {
            scale = 1 / scale;
          }

          return Transform.scale(
            scale: scale,
            child: Center(
              child: AspectRatio(
                aspectRatio: previewRatio,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CameraPreview(controller),
                    if (foregroundPainter != null)
                      CustomPaint(painter: foregroundPainter),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
