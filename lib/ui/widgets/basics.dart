import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// Settings-style leading icon: a white glyph on a colored rounded square.
class SymbolBadge extends StatelessWidget {
  const SymbolBadge(this.icon, this.color, {super.key, this.size = 29});

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size * 0.24),
      ),
      child: Icon(icon, size: size * 0.62, color: CupertinoColors.white),
    );
  }
}

/// Like SwiftUI's `ContentUnavailableView`: a symbol, a short title, one
/// line on why it's empty and what fills it, and an optional action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final secondary = InsightColors.secondaryLabel.resolveFrom(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: secondary),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: InsightText.title2.copyWith(
                color: InsightColors.label.resolveFrom(context),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: InsightText.subheadline.copyWith(color: secondary),
            ),
            if (action != null) ...[const SizedBox(height: 18), action!],
          ],
        ),
      ),
    );
  }
}

/// iOS 26 segmented control: a capsule track with a sliding capsule thumb
/// and no dividers.
class CapsuleSegments<T extends Object> extends StatelessWidget {
  const CapsuleSegments({
    super.key,
    required this.value,
    required this.segments,
    required this.onChanged,
  });

  final T value;
  final Map<T, String> segments;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final keys = segments.keys.toList();
    final index = keys.indexOf(value);
    final ink = InsightColors.label.resolveFrom(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    // Full width on phones; on wide panes it keeps a control's natural
    // size, as a Mac or iPad segmented control does, instead of a banner.
    return LayoutBuilder(
      builder: (context, outer) => Align(
        alignment: AlignmentDirectional.centerStart,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: outer.maxWidth > 600
                ? 112.0 * keys.length
                : outer.maxWidth,
          ),
          child: _track(context, keys, index, ink, dark, reduceMotion),
        ),
      ),
    );
  }

  Widget _track(
    BuildContext context,
    List<T> keys,
    int index,
    Color ink,
    bool dark,
    bool reduceMotion,
  ) {
    return Container(
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: ShapeDecoration(
        shape: const StadiumBorder(),
        color: InsightColors.fill.resolveFrom(context),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth / keys.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                left: w * index,
                top: 0,
                bottom: 0,
                width: w,
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    shape: const StadiumBorder(),
                    color: dark
                        ? const Color(0xFF636366)
                        : CupertinoColors.white,
                    shadows: const [
                      BoxShadow(
                        color: Color(0x1F000000),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  for (final k in keys)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: k == value,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            if (k == value) return;
                            HapticFeedback.selectionClick();
                            onChanged(k);
                          },
                          child: Center(
                            child: Text(
                              segments[k]!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: InsightText.subheadline.copyWith(
                                fontSize: 14,
                                color: ink,
                                fontWeight: k == value
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A round symbol button for use inside content (cards, panels), where
/// glass would vanish against the surface: a gray fill circle instead.
class FillIconButton extends StatelessWidget {
  const FillIconButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.size = 36,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size.square(InsightSpacing.minHitTarget),
        onPressed: onPressed,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: InsightColors.fill.resolveFrom(context),
          ),
          child: Icon(
            icon,
            size: size * 0.46,
            color: InsightColors.secondaryLabel.resolveFrom(context),
          ),
        ),
      ),
    );
  }
}

/// A status like On Time or Late as colored text with an optional symbol,
/// the way Apple marks state in a row: no badge or capsule behind it.
class StatusLabel extends StatelessWidget {
  const StatusLabel({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: InsightText.subheadline.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// A rounded content card on the grouped background. No shadow: the
/// grouped surface is the card.
class InsightCard extends StatelessWidget {
  const InsightCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: InsightColors.card.resolveFrom(context),
        borderRadius: BorderRadius.circular(InsightRadii.card),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Initials on Contacts' gray monogram, used where a student has no photo.
/// One look for everyone: color by name hash reads as random confetti.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({super.key, required this.name, this.size = 40});

  final String name;
  final double size;

  static const _top = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFA5ABB8),
    darkColor: Color(0xFF8E8E93),
  );
  static const _bottom = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF858994),
    darkColor: Color(0xFF636366),
  );

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    final first = parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_top.resolveFrom(context), _bottom.resolveFrom(context)],
        ),
      ),
      child: Text(
        _initials,
        style: InsightText.headline.copyWith(
          color: CupertinoColors.white,
          fontSize: size * 0.4,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

/// A Fitness-style progress ring with an optional label in the middle.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.progress,
    required this.color,
    this.size = 96,
    this.strokeWidth = 11,
    this.child,
  });

  /// 0–1.
  final double progress;
  final Color color;
  final double size;
  final double strokeWidth;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return SizedBox.square(
      dimension: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: progress.clamp(0.0, 1.0)),
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) => CustomPaint(
          painter: _RingPainter(
            progress: value,
            color: color,
            track: color.withValues(alpha: 0.18),
            strokeWidth: strokeWidth,
          ),
          child: Center(child: child),
        ),
        child: child,
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.color,
    required this.track,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final Color track;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(strokeWidth / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, 6.2832, false, paint..color = track);
    if (progress > 0) {
      canvas.drawArc(
        rect,
        -1.5708,
        6.2832 * progress,
        false,
        paint..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}

/// Headline figures in one card, like the numbers atop Stocks or Health:
/// a quiet label, a large value and an optional detail, divided by
/// hairlines. Two per row when the card is too narrow for all of them.
class StatStrip extends StatelessWidget {
  const StatStrip({super.key, required this.figures});

  final List<({String label, String value, String? detail})> figures;

  @override
  Widget build(BuildContext context) {
    final secondary = InsightColors.secondaryLabel.resolveFrom(context);
    final label = InsightColors.label.resolveFrom(context);
    final separator = InsightColors.separator.resolveFrom(context);

    Widget figure(({String label, String value, String? detail}) f) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          f.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: InsightText.footnote.copyWith(
            color: secondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          f.value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: InsightText.title2.copyWith(
            color: label,
            fontFeatures: InsightText.tabular,
          ),
        ),
        Text(
          f.detail ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: InsightText.footnote.copyWith(color: secondary),
        ),
      ],
    );

    return InsightCard(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: LayoutBuilder(
        builder: (context, c) {
          final perRow = c.maxWidth / figures.length >= 112
              ? figures.length
              : 2;
          final rows = [
            for (var i = 0; i < figures.length; i += perRow)
              figures.sublist(i, math.min(i + perRow, figures.length)),
          ];
          return Column(
            children: [
              for (final (r, row) in rows.indexed) ...[
                if (r > 0) const SizedBox(height: 16),
                IntrinsicHeight(
                  child: Row(
                    children: [
                      for (var i = 0; i < perRow; i++) ...[
                        if (i > 0) Container(width: 0.5, color: separator),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: i < row.length
                                ? figure(row[i])
                                : const SizedBox(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
