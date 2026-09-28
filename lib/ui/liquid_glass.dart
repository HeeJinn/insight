// An approximation of iOS 26 Liquid Glass for Flutter.
//
// Use it for the control layer only: tab bars, bar buttons, the back
// button, floating actions, menus. Never for content (cards, rows, charts).
//
// Ingredients, as Apple describes the material: a blur of what's behind,
// a saturation boost (what separates it from flat "glassmorphism"), a thin
// tint of the page's tone, a bright rim, and a soft shadow that stays
// outside the shape so the blur doesn't pick it up.

import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';

class LiquidGlass extends StatelessWidget {
  const LiquidGlass({
    super.key,
    required this.child,
    this.shape = const StadiumBorder(),
    this.tint,
    this.clear = false,
    this.shadow = true,
  });

  final Widget child;

  /// StadiumBorder for capsules, CircleBorder for round buttons,
  /// RoundedSuperellipseBorder/RoundedRectangleBorder for panels.
  final ShapeBorder shape;

  /// Stained glass for a prominent control (e.g. the accent color behind a
  /// primary action). Null for regular, colorless glass.
  final Color? tint;

  /// The highly translucent variant, only over photos and video.
  final bool clear;

  /// A soft shadow for glass that floats well clear of content.
  final bool shadow;

  static List<double> _saturation(double s) {
    const r = 0.2126, g = 0.7152, b = 0.0722;
    final i = 1 - s;
    return [
      i * r + s, i * g, i * b, 0, 0, //
      i * r, i * g + s, i * b, 0, 0,
      i * r, i * g, i * b + s, 0, 0,
      0, 0, 0, 1, 0,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    // Increase Contrast: glass turns nearly opaque, as the system does.
    final solid = MediaQuery.highContrastOf(context);

    final base =
        tint ?? (dark ? const Color(0xFF26282B) : const Color(0xFFFFFFFF));
    final alpha = solid
        ? 0.96
        : tint != null
        ? 0.82
        : clear
        ? (dark ? 0.16 : 0.10)
        : (dark ? 0.58 : 0.66);
    final blur = clear ? 10.0 : 22.0;

    return CustomPaint(
      painter: shadow ? _OuterShadow(shape: shape, dark: dark) : null,
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: shape),
        child: BackdropFilter(
          filter: ui.ImageFilter.compose(
            outer: ui.ColorFilter.matrix(_saturation(1.6)),
            inner: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          ),
          child: CustomPaint(
            foregroundPainter: _Rim(shape: shape, dark: dark),
            child: DecoratedBox(
              decoration: ShapeDecoration(
                shape: shape,
                color: base.withValues(alpha: alpha),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// The bright edge that makes glass read as a pane, brightest at the top
/// where light would catch it.
class _Rim extends CustomPainter {
  _Rim({required this.shape, required this.dark});
  final ShapeBorder shape;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final white = const Color(0xFFFFFFFF);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          white.withValues(alpha: dark ? 0.26 : 0.95),
          white.withValues(alpha: dark ? 0.05 : 0.35),
        ],
      ).createShader(rect);
    canvas.drawPath(shape.getOuterPath(rect.deflate(0.5)), paint);
  }

  @override
  bool shouldRepaint(_Rim old) => old.dark != dark || old.shape != shape;
}

/// A shadow painted only outside the shape, so it neither darkens the
/// glass nor gets pulled into the backdrop blur.
class _OuterShadow extends CustomPainter {
  _OuterShadow({required this.shape, required this.dark});
  final ShapeBorder shape;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final outline = shape.getOuterPath(rect);
    canvas.save();
    canvas.clipPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(rect.inflate(48)),
        outline,
      ),
    );
    canvas.drawPath(
      outline.shift(const Offset(0, 4)),
      Paint()
        ..color = const Color(0xFF000000).withValues(alpha: dark ? 0.35 : 0.10)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_OuterShadow old) =>
      old.dark != dark || old.shape != shape;
}

/// A round glass button holding one symbol, as iOS 26 puts in its bars
/// (back, close, more). Shrinks a touch under the finger.
class GlassIconButton extends StatefulWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.size = 44,
  });

  final IconData icon;

  /// What VoiceOver reads: "Back", "Close", "More".
  final String semanticLabel;
  final VoidCallback? onPressed;
  final double size;

  @override
  State<GlassIconButton> createState() => _GlassIconButtonState();
}

class _GlassIconButtonState extends State<GlassIconButton> {
  bool _down = false;

  void _set(bool down) {
    if (down != _down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoColors.label.resolveFrom(context);
    return Semantics(
      button: true,
      enabled: widget.onPressed != null,
      label: widget.semanticLabel,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _down ? 0.9 : 1,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          child: SizedBox.square(
            dimension: widget.size,
            child: LiquidGlass(
              shape: const CircleBorder(),
              shadow: false,
              child: Center(
                child: Icon(widget.icon, size: widget.size * 0.45, color: ink),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
