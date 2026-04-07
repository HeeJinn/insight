import 'package:flutter/material.dart';
import '../app_theme.dart';

class AppBackground extends StatelessWidget {
  final Widget child;

  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            cs.surface,
            cs.surface.withValues(alpha: 0.94),
          ],
        ),
      ),
      child: child,
    );
  }
}

class AppPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Gradient? gradient;
  final Color? color;
  final double radius;
  final bool elevated;
  final Color? borderColor;

  const AppPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.gradient,
    this.color,
    this.radius = 30,
    this.elevated = true,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final border = Theme.of(context).dividerColor;
    final surface = Theme.of(context).colorScheme.surface;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: borderColor ?? border),
    );

    final content = Padding(padding: padding, child: child);

    if (gradient != null) {
      return Card(
        elevation: elevated ? 1 : 0,
        color: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: DecoratedBox(decoration: BoxDecoration(gradient: gradient), child: content),
      );
    }

    return Card(
      elevation: elevated ? 1 : 0,
      color: color ?? surface,
      surfaceTintColor: Colors.transparent,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: content,
    );
  }
}

class AppPillTag extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final EdgeInsetsGeometry? padding;

  const AppPillTag({
    super.key,
    required this.label,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = foregroundColor ?? Theme.of(context).colorScheme.onSurface;
    final labelWidget = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: textColor, fontWeight: FontWeight.w700),
    );

    return Container(
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: backgroundColor ?? Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: icon == null
          ? labelWidget
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: textColor),
                const SizedBox(width: 8),
                Flexible(child: labelWidget),
              ],
            ),
    );
  }
}

class AppSectionHeading extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final bool compact;

  const AppSectionHeading({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.compact,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final titleStyle = compact
        ? Theme.of(context).textTheme.headlineMedium
        : Theme.of(context).textTheme.displayMedium;

    final leading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppPillTag(
          label: eyebrow,
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          foregroundColor: AppTheme.muted,
        ),
        const SizedBox(height: 16),
        Text(title, style: titleStyle),
        const SizedBox(height: 10),
        Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
      ],
    );

    if (compact || trailing == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          leading,
          if (trailing != null) ...[const SizedBox(height: 18), trailing!],
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: leading),
        const SizedBox(width: 20),
        trailing!,
      ],
    );
  }
}

