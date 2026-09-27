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

/// A small rounded-rectangle "pill" for statuses like On time / Late.
class StatusPill extends StatelessWidget {
  const StatusPill({
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: ShapeDecoration(
        shape: const StadiumBorder(),
        color: color.withValues(alpha: 0.16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: InsightText.footnote.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
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

/// Initials in a tinted circle, used where a student has no photo.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({super.key, required this.name, this.size = 40});

  final String name;
  final double size;

  static const _palette = <CupertinoDynamicColor>[
    CupertinoColors.systemBlue,
    CupertinoColors.systemIndigo,
    CupertinoColors.systemPurple,
    CupertinoColors.systemTeal,
    CupertinoColors.systemOrange,
    CupertinoColors.systemPink,
    CupertinoColors.systemGreen,
  ];

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    final first = parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final color = _palette[name.hashCode.abs() % _palette.length].resolveFrom(
      context,
    );
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.18),
      ),
      child: Text(
        _initials,
        style: InsightText.headline.copyWith(
          color: color,
          fontSize: size * 0.38,
          letterSpacing: 0,
        ),
      ),
    );
  }
}
