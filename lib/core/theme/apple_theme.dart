import 'package:flutter/material.dart';

/// Standard Apple San Francisco-inspired Typography Scale, set in Inter,
/// with tabular figure support.
///
/// Color is intentionally not part of this scale — pair these styles with
/// `context.appColors` (see `AppColorsExtension` in `app_theme.dart`), the
/// single source of truth for color tokens.
class AppleTypography {
  const AppleTypography._();

  static const String fontFamily = 'Inter';

  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];

  // Large Title (34pt, Bold, -0.8 tracking)
  static const TextStyle largeTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 34,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.8,
    height: 1.2,
  );

  // Title 1 (28pt, Bold, -0.6 tracking)
  static const TextStyle title1 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
    height: 1.25,
  );

  // Title 2 (22pt, Bold, -0.4 tracking)
  static const TextStyle title2 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
    height: 1.3,
  );

  // Title 3 (20pt, SemiBold, -0.3 tracking)
  static const TextStyle title3 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
    height: 1.3,
  );

  // Headline (17pt, SemiBold, -0.4 tracking)
  static const TextStyle headline = TextStyle(
    fontFamily: fontFamily,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
    height: 1.35,
  );

  // Body (17pt, Regular, -0.2 tracking)
  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 17,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.2,
    height: 1.4,
  );

  // Callout (16pt, Regular, -0.1 tracking)
  static const TextStyle callout = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.1,
    height: 1.35,
  );

  // Subhead (15pt, Regular)
  static const TextStyle subhead = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.0,
    height: 1.35,
  );

  // Footnote (13pt, Regular, 0.1 tracking)
  static const TextStyle footnote = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
    height: 1.35,
  );

  // Caption 1 (12pt, Regular, 0.2 tracking)
  static const TextStyle caption1 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.2,
    height: 1.3,
  );

  // Caption 2 (11pt, Regular, 0.2 tracking)
  static const TextStyle caption2 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.2,
    height: 1.3,
  );

  // Monospace / Tabular numbers
  static TextStyle tabularNumber({
    double fontSize = 17,
    FontWeight fontWeight = FontWeight.w600,
    Color? color,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: -0.3,
      fontFeatures: tabular,
      color: color,
    );
  }
}
