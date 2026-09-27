import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

/// Insight's design tokens, expressed as iOS roles.
///
/// Colors come from Cupertino's dynamic system colors so light, dark and
/// Increase Contrast all work; resolve them with `.resolveFrom(context)`.
/// The brand accent is system blue and marks interactive or selected
/// things only. Chrome stays monochrome.
class InsightColors {
  const InsightColors._();

  static const CupertinoDynamicColor accent = CupertinoColors.systemBlue;

  // Page and surfaces.
  static const CupertinoDynamicColor groupedBackground =
      CupertinoColors.systemGroupedBackground;
  static const CupertinoDynamicColor card =
      CupertinoColors.secondarySystemGroupedBackground;
  static const CupertinoDynamicColor elevatedCard =
      CupertinoColors.tertiarySystemGroupedBackground;

  // Ink.
  static const CupertinoDynamicColor label = CupertinoColors.label;
  static const CupertinoDynamicColor secondaryLabel =
      CupertinoColors.secondaryLabel;
  static const CupertinoDynamicColor tertiaryLabel =
      CupertinoColors.tertiaryLabel;
  static const CupertinoDynamicColor separator = CupertinoColors.separator;
  static const CupertinoDynamicColor fill = CupertinoColors.tertiarySystemFill;

  // Status.
  static const CupertinoDynamicColor success = CupertinoColors.systemGreen;
  static const CupertinoDynamicColor warning = CupertinoColors.systemOrange;
  static const CupertinoDynamicColor danger = CupertinoColors.systemRed;

  /// The sidebar's source-list tint on desktop, a shade off the page.
  static const CupertinoDynamicColor sidebar =
      CupertinoDynamicColor.withBrightness(
        color: Color(0xFFEDEDF2),
        darkColor: Color(0xFF161618),
      );
}

/// One radius per kind of element, app-wide. Inner radii are concentric:
/// inner = outer - padding.
class InsightRadii {
  const InsightRadii._();

  static const double section = 26;
  static const double card = 22;
  static const double sheet = 38;
  static const double menu = 22;
  static const double thumbnail = 12;
  static const double badge = 7;
  static const double capsule = 999;
}

class InsightSpacing {
  const InsightSpacing._();

  /// Side margin on phones.
  static const double margin = 16;

  /// Side margin in wide admin content panes.
  static const double wideMargin = 28;

  static const double sectionGap = 28;
  static const double minHitTarget = 44;
}

/// Layout thresholds for the adaptive admin shell.
class InsightBreakpoints {
  const InsightBreakpoints._();

  /// At or above this width the admin area uses a sidebar instead of the
  /// floating tab bar.
  static const double sidebar = 900;

  static bool usesSidebar(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= sidebar;
}

/// True on Apple platforms, where the Cupertino default (San Francisco)
/// resolves. Everywhere else the app uses bundled Inter, the closest free
/// match, so Windows and Android read like iOS instead of Segoe/Roboto.
bool get isApplePlatform =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS);

/// Desktop platforms, where the app opens straight into the kiosk.
bool get isDesktopPlatform =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux);

String? get _fallbackFontFamily => isApplePlatform ? null : 'Inter';

/// Text styles on the iOS Dynamic Type scale, in the platform-appropriate
/// family. Color is left to the ambient `DefaultTextStyle` or the caller.
class InsightText {
  const InsightText._();

  static TextStyle _s(
    double size,
    double height,
    FontWeight weight,
    double tracking,
  ) => TextStyle(
    fontFamily: _fallbackFontFamily ?? 'CupertinoSystemText',
    fontSize: size,
    height: height / size,
    fontWeight: weight,
    letterSpacing: tracking,
  );

  static final TextStyle largeTitle = _s(34, 41, FontWeight.w700, 0.4);
  static final TextStyle title1 = _s(28, 34, FontWeight.w700, 0.36);
  static final TextStyle title2 = _s(22, 28, FontWeight.w700, 0.35);
  static final TextStyle title3 = _s(20, 25, FontWeight.w600, 0.38);
  static final TextStyle headline = _s(17, 22, FontWeight.w600, -0.41);
  static final TextStyle body = _s(17, 22, FontWeight.w400, -0.41);
  static final TextStyle callout = _s(16, 21, FontWeight.w400, -0.32);
  static final TextStyle subheadline = _s(15, 20, FontWeight.w400, -0.24);
  static final TextStyle footnote = _s(13, 18, FontWeight.w400, -0.08);
  static final TextStyle caption1 = _s(12, 16, FontWeight.w400, 0);
  static final TextStyle caption2 = _s(11, 13, FontWeight.w400, 0.07);

  /// For numbers that line up in columns or tick over live.
  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];
}

/// Builds the app's Cupertino theme. [brightness] null follows the system.
CupertinoThemeData insightCupertinoTheme({Brightness? brightness}) {
  final base = CupertinoThemeData(
    brightness: brightness,
    primaryColor: InsightColors.accent,
    scaffoldBackgroundColor: InsightColors.groupedBackground,
    // Bars are clear at rest and pick up a background only when content
    // scrolls beneath them.
    barBackgroundColor: const Color(0x00000000),
  );

  final family = _fallbackFontFamily;
  if (family == null) return base;

  final t = base.textTheme;
  TextStyle f(TextStyle s) => s.copyWith(fontFamily: family);
  return base.copyWith(
    textTheme: t.copyWith(
      textStyle: f(t.textStyle),
      actionTextStyle: f(t.actionTextStyle),
      actionSmallTextStyle: f(t.actionSmallTextStyle),
      tabLabelTextStyle: f(t.tabLabelTextStyle),
      navTitleTextStyle: f(t.navTitleTextStyle),
      navLargeTitleTextStyle: f(t.navLargeTitleTextStyle),
      navActionTextStyle: f(t.navActionTextStyle),
      pickerTextStyle: f(t.pickerTextStyle),
      dateTimePickerTextStyle: f(t.dateTimePickerTextStyle),
    ),
  );
}
