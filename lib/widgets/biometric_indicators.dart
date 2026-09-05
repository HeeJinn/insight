import 'package:flutter/material.dart';
import '../app_theme.dart';

/// Animated pulsing status dot for live instrumentation indicators.
class PulseDot extends StatefulWidget {
  final Color color;
  final double size;
  final bool animate;

  const PulseDot({
    super.key,
    required this.color,
    this.size = 8.0,
    this.animate = true,
  });

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.animate) {
      return Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
        ),
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final scale = 0.85 + (_controller.value * 0.3);
        final opacity = 0.65 + (_controller.value * 0.35);
        return Transform.scale(
          scale: scale,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: widget.color.withValues(alpha: opacity),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.4 * _controller.value),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A precision 5-sample biometric completeness indicator.
/// Shows 5 micro-bars representing facial embedding samples.
class BiometricQualityPips extends StatelessWidget {
  final int sampleCount;
  final int targetCount;
  final bool compact;

  const BiometricQualityPips({
    super.key,
    required this.sampleCount,
    this.targetCount = 5,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isComplete = sampleCount >= targetCount;
    final activeColor = isComplete ? colors.success : colors.warning;
    final inactiveColor = Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(targetCount, (index) {
            final filled = index < sampleCount;
            return Container(
              margin: const EdgeInsets.only(right: 3),
              width: compact ? 7 : 10,
              height: compact ? 4 : 5,
              decoration: BoxDecoration(
                color: filled ? activeColor : inactiveColor,
                borderRadius: BorderRadius.circular(2),
                boxShadow: filled && isComplete
                    ? [
                        BoxShadow(
                          color: activeColor.withValues(alpha: 0.35),
                          blurRadius: 4,
                        ),
                      ]
                    : null,
              ),
            );
          }),
        ),
        const SizedBox(width: 5),
        Text(
          '$sampleCount/$targetCount',
          style: TextStyle(
            fontSize: compact ? 10 : 11,
            fontWeight: FontWeight.w700,
            color: activeColor,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// Technical telemetry badge for hardware and system states.
class TelemetryBadge extends StatelessWidget {
  final String label;
  final Color? statusColor;
  final IconData? icon;
  final bool isLive;
  final EdgeInsetsGeometry padding;

  const TelemetryBadge({
    super.key,
    required this.label,
    Color? color,
    Color? statusColor,
    this.icon,
    bool? pulse,
    bool isLive = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
  })  : statusColor = statusColor ?? color,
        isLive = pulse ?? isLive;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = statusColor ?? context.appColors.accent;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: isDark ? 0.14 : 0.09),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: effectiveColor.withValues(alpha: isDark ? 0.28 : 0.2),
          width: 0.9,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLive) ...[
            PulseDot(color: effectiveColor, size: 6),
            const SizedBox(width: 6),
          ] else if (icon != null) ...[
            Icon(icon, size: 12, color: effectiveColor),
            const SizedBox(width: 5),
          ],
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.9,
              color: effectiveColor,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Precision reticle corner frame painter.
class ReticleCornerPainter extends CustomPainter {
  final Color color;
  final double length;
  final double thickness;
  final double cornerRadius;

  ReticleCornerPainter({
    required this.color,
    this.length = 16.0,
    this.thickness = 2.0,
    this.cornerRadius = 6.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;

    // Top-Left
    canvas.drawLine(Offset(cornerRadius, 0), Offset(length, 0), paint);
    canvas.drawLine(Offset(0, cornerRadius), Offset(0, length), paint);
    canvas.drawArc(
      Rect.fromLTWH(0, 0, cornerRadius * 2, cornerRadius * 2),
      3.14159,
      1.57079,
      false,
      paint,
    );

    // Top-Right
    canvas.drawLine(Offset(w - length, 0), Offset(w - cornerRadius, 0), paint);
    canvas.drawLine(Offset(w, cornerRadius), Offset(w, length), paint);
    canvas.drawArc(
      Rect.fromLTWH(w - cornerRadius * 2, 0, cornerRadius * 2, cornerRadius * 2),
      -1.57079,
      1.57079,
      false,
      paint,
    );

    // Bottom-Left
    canvas.drawLine(Offset(0, h - length), Offset(0, h - cornerRadius), paint);
    canvas.drawLine(Offset(cornerRadius, h), Offset(length, h), paint);
    canvas.drawArc(
      Rect.fromLTWH(0, h - cornerRadius * 2, cornerRadius * 2, cornerRadius * 2),
      1.57079,
      1.57079,
      false,
      paint,
    );

    // Bottom-Right
    canvas.drawLine(Offset(w, h - length), Offset(w, h - cornerRadius), paint);
    canvas.drawLine(Offset(w - length, h), Offset(w - cornerRadius, h), paint);
    canvas.drawArc(
      Rect.fromLTWH(w - cornerRadius * 2, h - cornerRadius * 2, cornerRadius * 2, cornerRadius * 2),
      0,
      1.57079,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant ReticleCornerPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.length != length ||
      oldDelegate.thickness != thickness;
}
