import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../app_theme.dart';
import '../providers/settings_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'biometric_indicators.dart';
import 'responsive_utils.dart';

export 'apple_chrome.dart';

class AppBackground extends StatelessWidget {
  final Widget child;

  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
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
  final bool showReticles;

  const AppPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.gradient,
    this.color,
    this.radius = 12,
    this.elevated = false,
    this.borderColor,
    this.showReticles = false,
  });

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final resolvedBorderColor = borderColor ?? context.appColors.border;

    Widget content = Padding(padding: padding, child: child);

    if (showReticles) {
      final reticleColor = context.appColors.accent.withValues(alpha: isDark ? 0.6 : 0.4);
      content = CustomPaint(
        foregroundPainter: ReticleCornerPainter(
          color: reticleColor,
          length: 12,
          thickness: 1.5,
          cornerRadius: radius,
        ),
        child: content,
      );
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? surface) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: resolvedBorderColor, width: 0.5),
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = foregroundColor ??
        (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155));
    final defaultBg = isDark
        ? const Color(0x1F2B3648)
        : const Color(0xFFF1F5F9);
    final borderColor = isDark
        ? const Color(0x33334155)
        : const Color(0xFFE2E8F0);

    final labelWidget = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: textColor,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      ),
    );

    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor ?? defaultBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: (foregroundColor != null)
              ? foregroundColor!.withValues(alpha: 0.25)
              : borderColor,
          width: 0.8,
        ),
      ),
      child: icon == null
          ? labelWidget
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 13, color: textColor),
                const SizedBox(width: 5),
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
          backgroundColor: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest,
          foregroundColor: context.appColors.mutedText,
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

class AppPageScaffold extends ConsumerWidget {
  final String title;
  final String subtitle;
  final String? eyebrow;
  final Widget child;
  final List<Widget>? actions;
  final bool sliverLike;

  const AppPageScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.eyebrow,
    this.actions,
    this.sliverLike = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final compactMode = ref.watch(compactModeProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final compact = compactMode || AppBreakpoints.isCompact(width);
        final contentWidth = AppBreakpoints.contentWidth(width);
        final padding = AppBreakpoints.pagePadding(width);
        return SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: contentWidth),
              child: Padding(
                padding: padding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppPageHeader(
                      title: title,
                      subtitle: subtitle,
                      eyebrow: eyebrow,
                      compact: compact,
                      actions: actions,
                    ),
                    SizedBox(height: AppSpacing.sectionGap(compact)),
                    Expanded(child: child),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class AppPageHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool compact;
  final String? eyebrow;
  final List<Widget>? actions;

  const AppPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.compact,
    this.eyebrow,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (eyebrow != null) ...[
                Text(
                  eyebrow!.toUpperCase(),
                  style: AppleTypography.caption1.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                    color: context.appColors.secondaryText,
                  ),
                ),
                const SizedBox(height: 4),
              ],
              Text(
                title,
                style: AppleTypography.largeTitle.copyWith(
                  color: context.appColors.primaryText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: AppleTypography.subhead.copyWith(
                  color: context.appColors.secondaryText,
                ),
              ),
            ],
          ),
        ),
        if (actions != null && actions!.isNotEmpty)
          Wrap(spacing: 8, runSpacing: 6, children: actions!),
      ],
    );
  }
}

class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: AppPanel(
        radius: 18,
        showReticles: true,
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        elevated: false,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // "Empty State" by Creative Salt & Pepper, via LottieFiles
            // (Lottie Simple License — free for commercial use).
            SizedBox(
              width: 140,
              height: 140,
              child: Lottie.asset(
                'assets/animations/empty_state.json',
                repeat: true,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: colors.accent.withValues(alpha: isDark ? 0.16 : 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: colors.accent.withValues(alpha: isDark ? 0.3 : 0.15),
                      width: 0.9,
                    ),
                  ),
                  child: Icon(
                    icon,
                    size: 26,
                    color: colors.accent,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
