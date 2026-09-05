import 'package:flutter/material.dart';

import 'models/flavor_profile.dart';

@immutable
class AppColorsExtension extends ThemeExtension<AppColorsExtension> {
  final Color background;
  final Color surface;
  final Color elevatedSurface;
  final Color primary;
  final Color primaryText;
  final Color secondaryText;
  final Color mutedText;
  final Color border;
  final Color button;
  final Color buttonText;
  final Color accent;
  final Color accentDark;
  final Color accentSoft;
  final Color blue;
  final Color blueSoft;
  final Color orange;
  final Color orangeSoft;
  final Color pink;
  final Color pinkSoft;
  final Color lilac;
  final Color success;
  final Color successSoft;
  final Color danger;
  final Color dangerSoft;
  final Color warning;
  final Color warningSoft;

  const AppColorsExtension({
    required this.background,
    required this.surface,
    required this.elevatedSurface,
    required this.primary,
    required this.primaryText,
    required this.secondaryText,
    required this.mutedText,
    required this.border,
    required this.button,
    required this.buttonText,
    required this.accent,
    required this.accentDark,
    required this.accentSoft,
    required this.blue,
    required this.blueSoft,
    required this.orange,
    required this.orangeSoft,
    required this.pink,
    required this.pinkSoft,
    required this.lilac,
    required this.success,
    required this.successSoft,
    required this.danger,
    required this.dangerSoft,
    required this.warning,
    required this.warningSoft,
  });

  Color get amber => warning;
  Color get amberSoft => warningSoft;

  static const AppColorsExtension light = AppColorsExtension(
    background: Color(0xFFF8F9FA),
    surface: Color(0xFFFFFFFF),
    elevatedSurface: Color(0xFFF1F4F9),
    primary: Color(0xFF0F172A),
    primaryText: Color(0xFF0F172A),
    secondaryText: Color(0xFF475569),
    mutedText: Color(0xFF94A3B8),
    border: Color(0xFFE2E8F0),
    button: Color(0xFF0F172A),
    buttonText: Color(0xFFFFFFFF),
    accent: Color(0xFF4F46E5),
    accentDark: Color(0xFF4338CA),
    accentSoft: Color(0xFFEEF2FF),
    blue: Color(0xFF2563EB),
    blueSoft: Color(0xFFEFF6FF),
    orange: Color(0xFFF59E0B),
    orangeSoft: Color(0xFFFEF3C7),
    pink: Color(0xFFEC4899),
    pinkSoft: Color(0xFFFDF2F8),
    lilac: Color(0xFFF5F3FF),
    success: Color(0xFF00D284),
    successSoft: Color(0xFFD1FAE5),
    danger: Color(0xFFEF4444),
    dangerSoft: Color(0xFFFEE2E2),
    warning: Color(0xFFF59E0B),
    warningSoft: Color(0xFFFEF3C7),
  );

  static const AppColorsExtension dark = AppColorsExtension(
    background: Color(0xFF0A0C10),
    surface: Color(0xFF121620),
    elevatedSurface: Color(0xFF181E2C),
    primary: Color(0xFFF8FAFC),
    primaryText: Color(0xFFF8FAFC),
    secondaryText: Color(0xFF94A3B8),
    mutedText: Color(0xFF64748B),
    border: Color(0xFF242C3D),
    button: Color(0xFFF8FAFC),
    buttonText: Color(0xFF0A0C10),
    accent: Color(0xFF6366F1),
    accentDark: Color(0xFF4F46E5),
    accentSoft: Color(0xFF1E2238),
    blue: Color(0xFF38BDF8),
    blueSoft: Color(0xFF0C2438),
    orange: Color(0xFFFBBF24),
    orangeSoft: Color(0xFF3A2308),
    pink: Color(0xFFF472B6),
    pinkSoft: Color(0xFF3D1024),
    lilac: Color(0xFF2A1C47),
    success: Color(0xFF00E599),
    successSoft: Color(0xFF063321),
    danger: Color(0xFFF87171),
    dangerSoft: Color(0xFF3F1111),
    warning: Color(0xFFFBBF24),
    warningSoft: Color(0xFF3A2308),
  );

  @override
  AppColorsExtension copyWith({
    Color? background,
    Color? surface,
    Color? elevatedSurface,
    Color? primary,
    Color? primaryText,
    Color? secondaryText,
    Color? mutedText,
    Color? border,
    Color? button,
    Color? buttonText,
    Color? accent,
    Color? accentDark,
    Color? accentSoft,
    Color? blue,
    Color? blueSoft,
    Color? orange,
    Color? orangeSoft,
    Color? pink,
    Color? pinkSoft,
    Color? lilac,
    Color? success,
    Color? successSoft,
    Color? danger,
    Color? dangerSoft,
    Color? warning,
    Color? warningSoft,
  }) {
    return AppColorsExtension(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      elevatedSurface: elevatedSurface ?? this.elevatedSurface,
      primary: primary ?? this.primary,
      primaryText: primaryText ?? this.primaryText,
      secondaryText: secondaryText ?? this.secondaryText,
      mutedText: mutedText ?? this.mutedText,
      border: border ?? this.border,
      button: button ?? this.button,
      buttonText: buttonText ?? this.buttonText,
      accent: accent ?? this.accent,
      accentDark: accentDark ?? this.accentDark,
      accentSoft: accentSoft ?? this.accentSoft,
      blue: blue ?? this.blue,
      blueSoft: blueSoft ?? this.blueSoft,
      orange: orange ?? this.orange,
      orangeSoft: orangeSoft ?? this.orangeSoft,
      pink: pink ?? this.pink,
      pinkSoft: pinkSoft ?? this.pinkSoft,
      lilac: lilac ?? this.lilac,
      success: success ?? this.success,
      successSoft: successSoft ?? this.successSoft,
      danger: danger ?? this.danger,
      dangerSoft: dangerSoft ?? this.dangerSoft,
      warning: warning ?? this.warning,
      warningSoft: warningSoft ?? this.warningSoft,
    );
  }

  @override
  AppColorsExtension lerp(ThemeExtension<AppColorsExtension>? other, double t) {
    if (other is! AppColorsExtension) {
      return this;
    }
    return AppColorsExtension(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      elevatedSurface: Color.lerp(elevatedSurface, other.elevatedSurface, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryText: Color.lerp(primaryText, other.primaryText, t)!,
      secondaryText: Color.lerp(secondaryText, other.secondaryText, t)!,
      mutedText: Color.lerp(mutedText, other.mutedText, t)!,
      border: Color.lerp(border, other.border, t)!,
      button: Color.lerp(button, other.button, t)!,
      buttonText: Color.lerp(buttonText, other.buttonText, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentDark: Color.lerp(accentDark, other.accentDark, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      blue: Color.lerp(blue, other.blue, t)!,
      blueSoft: Color.lerp(blueSoft, other.blueSoft, t)!,
      orange: Color.lerp(orange, other.orange, t)!,
      orangeSoft: Color.lerp(orangeSoft, other.orangeSoft, t)!,
      pink: Color.lerp(pink, other.pink, t)!,
      pinkSoft: Color.lerp(pinkSoft, other.pinkSoft, t)!,
      lilac: Color.lerp(lilac, other.lilac, t)!,
      success: Color.lerp(success, other.success, t)!,
      successSoft: Color.lerp(successSoft, other.successSoft, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerSoft: Color.lerp(dangerSoft, other.dangerSoft, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningSoft: Color.lerp(warningSoft, other.warningSoft, t)!,
    );
  }
}

@immutable
class AppDecorationsExtension extends ThemeExtension<AppDecorationsExtension> {
  final BoxDecoration cardDecoration;
  final BoxDecoration panelDecoration;
  final double cardRadius;
  final double buttonRadius;
  final double inputRadius;
  final List<BoxShadow> panelShadow;
  final LinearGradient pageGradient;
  final LinearGradient accentGradient;
  final LinearGradient blueGradient;
  final LinearGradient orangeGradient;
  final LinearGradient pinkGradient;

  const AppDecorationsExtension({
    required this.cardDecoration,
    required this.panelDecoration,
    required this.cardRadius,
    required this.buttonRadius,
    required this.inputRadius,
    required this.panelShadow,
    required this.pageGradient,
    required this.accentGradient,
    required this.blueGradient,
    required this.orangeGradient,
    required this.pinkGradient,
  });

  static const AppDecorationsExtension light = AppDecorationsExtension(
    cardRadius: 16.0,
    buttonRadius: 14.0,
    inputRadius: 14.0,
    panelShadow: [
      BoxShadow(
        color: Color(0x0A000000),
        blurRadius: 16,
        offset: Offset(0, 4),
      ),
    ],
    pageGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFFFFFFF), Color(0xFFF5F5F7)],
    ),
    accentGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
    ),
    blueGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF60A5FA), Color(0xFF2563EB)],
    ),
    orangeGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFFDBA74), Color(0xFFF97316)],
    ),
    pinkGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFF472B6), Color(0xFFEC4899)],
    ),
    cardDecoration: BoxDecoration(
      color: Color(0xFFF5F5F7),
      borderRadius: BorderRadius.all(Radius.circular(16)),
      border: Border.fromBorderSide(BorderSide(color: Color(0xFFE8E8ED))),
    ),
    panelDecoration: BoxDecoration(
      color: Color(0xFFF5F5F7),
      borderRadius: BorderRadius.all(Radius.circular(16)),
      border: Border.fromBorderSide(BorderSide(color: Color(0xFFE8E8ED))),
      boxShadow: [
        BoxShadow(
          color: Color(0x0A000000),
          blurRadius: 16,
          offset: Offset(0, 4),
        ),
      ],
    ),
  );

  static const AppDecorationsExtension dark = AppDecorationsExtension(
    cardRadius: 16.0,
    buttonRadius: 14.0,
    inputRadius: 14.0,
    panelShadow: [
      BoxShadow(
        color: Color(0x40000000),
        blurRadius: 16,
        offset: Offset(0, 4),
      ),
    ],
    pageGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF000000), Color(0xFF1D1D1F)],
    ),
    accentGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF818CF8), Color(0xFF6366F1)],
    ),
    blueGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF93C5FD), Color(0xFF60A5FA)],
    ),
    orangeGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFFED7AA), Color(0xFFFB923C)],
    ),
    pinkGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFFBCFE8), Color(0xFFF472B6)],
    ),
    cardDecoration: BoxDecoration(
      color: Color(0xFF1D1D1F),
      borderRadius: BorderRadius.all(Radius.circular(16)),
      border: Border.fromBorderSide(BorderSide(color: Color(0xFF38383A))),
    ),
    panelDecoration: BoxDecoration(
      color: Color(0xFF1D1D1F),
      borderRadius: BorderRadius.all(Radius.circular(16)),
      border: Border.fromBorderSide(BorderSide(color: Color(0xFF38383A))),
      boxShadow: [
        BoxShadow(
          color: Color(0x40000000),
          blurRadius: 16,
          offset: Offset(0, 4),
        ),
      ],
    ),
  );

  @override
  AppDecorationsExtension copyWith({
    BoxDecoration? cardDecoration,
    BoxDecoration? panelDecoration,
    double? cardRadius,
    double? buttonRadius,
    double? inputRadius,
    List<BoxShadow>? panelShadow,
    LinearGradient? pageGradient,
    LinearGradient? accentGradient,
    LinearGradient? blueGradient,
    LinearGradient? orangeGradient,
    LinearGradient? pinkGradient,
  }) {
    return AppDecorationsExtension(
      cardDecoration: cardDecoration ?? this.cardDecoration,
      panelDecoration: panelDecoration ?? this.panelDecoration,
      cardRadius: cardRadius ?? this.cardRadius,
      buttonRadius: buttonRadius ?? this.buttonRadius,
      inputRadius: inputRadius ?? this.inputRadius,
      panelShadow: panelShadow ?? this.panelShadow,
      pageGradient: pageGradient ?? this.pageGradient,
      accentGradient: accentGradient ?? this.accentGradient,
      blueGradient: blueGradient ?? this.blueGradient,
      orangeGradient: orangeGradient ?? this.orangeGradient,
      pinkGradient: pinkGradient ?? this.pinkGradient,
    );
  }

  @override
  AppDecorationsExtension lerp(
    ThemeExtension<AppDecorationsExtension>? other,
    double t,
  ) {
    if (other is! AppDecorationsExtension) {
      return this;
    }
    return AppDecorationsExtension(
      cardDecoration: BoxDecoration.lerp(cardDecoration, other.cardDecoration, t)!,
      panelDecoration: BoxDecoration.lerp(panelDecoration, other.panelDecoration, t)!,
      cardRadius: (cardRadius + (other.cardRadius - cardRadius) * t),
      buttonRadius: (buttonRadius + (other.buttonRadius - buttonRadius) * t),
      inputRadius: (inputRadius + (other.inputRadius - inputRadius) * t),
      panelShadow: BoxShadow.lerpList(panelShadow, other.panelShadow, t) ?? panelShadow,
      pageGradient: LinearGradient.lerp(pageGradient, other.pageGradient, t)!,
      accentGradient: LinearGradient.lerp(accentGradient, other.accentGradient, t)!,
      blueGradient: LinearGradient.lerp(blueGradient, other.blueGradient, t)!,
      orangeGradient: LinearGradient.lerp(orangeGradient, other.orangeGradient, t)!,
      pinkGradient: LinearGradient.lerp(pinkGradient, other.pinkGradient, t)!,
    );
  }
}

extension AppThemeContextExtension on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  TextTheme get textTheme => Theme.of(this).textTheme;
  AppColorsExtension get appColors =>
      Theme.of(this).extension<AppColorsExtension>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? AppColorsExtension.dark
          : AppColorsExtension.light);
  AppDecorationsExtension get appDecorations =>
      Theme.of(this).extension<AppDecorationsExtension>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? AppDecorationsExtension.dark
          : AppDecorationsExtension.light);
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
}

class AppTheme {
  // Light mode palette
  static const Color lightBackground = Color(0xFFF8F9FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightElevatedSurface = Color(0xFFF1F4F9);
  static const Color lightPrimary = Color(0xFF0F172A);
  static const Color lightPrimaryText = Color(0xFF0F172A);
  static const Color lightSecondaryText = Color(0xFF475569);
  static const Color lightMutedText = Color(0xFF94A3B8);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightButton = Color(0xFF0F172A);
  static const Color lightButtonText = Color(0xFFFFFFFF);

  // Dark mode palette
  static const Color darkBackground = Color(0xFF0A0C10);
  static const Color darkSurface = Color(0xFF121620);
  static const Color darkElevatedSurface = Color(0xFF181E2C);
  static const Color darkPrimary = Color(0xFFF8FAFC);
  static const Color darkPrimaryText = Color(0xFFF8FAFC);
  static const Color darkSecondaryText = Color(0xFF94A3B8);
  static const Color darkMutedText = Color(0xFF64748B);
  static const Color darkBorder = Color(0xFF242C3D);
  static const Color darkButton = Color(0xFFF8FAFC);
  static const Color darkButtonText = Color(0xFF0A0C10);

  // Semantic fallbacks for static backward compatibility
  static const Color background = lightBackground;
  static const Color backgroundSoft = lightSurface;
  static const Color surface = lightSurface;
  static const Color surfaceSoft = Color(0xFFF1F4F9);
  static const Color ink = lightPrimaryText;
  static const Color muted = lightMutedText;
  static const Color border = lightBorder;

  static const Color accent = Color(0xFF4F46E5);
  static const Color accentDark = Color(0xFF4338CA);
  static const Color accentSoft = Color(0xFFEEF2FF);

  static const Color blue = Color(0xFF2563EB);
  static const Color blueSoft = Color(0xFFEFF6FF);
  static const Color orange = Color(0xFFF59E0B);
  static const Color orangeSoft = Color(0xFFFEF3C7);
  static const Color pink = Color(0xFFEC4899);
  static const Color pinkSoft = Color(0xFFFDF2F8);
  static const Color lilac = Color(0xFFF5F3FF);
  static const Color success = Color(0xFF00D284);
  static const Color danger = Color(0xFFEF4444);
  static const Color dangerSoft = Color(0xFFFEE2E2);
  static const Color warningSoft = Color(0xFFFEF3C7);

  static const LinearGradient pageGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [lightBackground, lightSurface],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, accentDark],
  );

  static const LinearGradient blueGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF60A5FA), blue],
  );

  static const LinearGradient orangeGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFDBA74), orange],
  );

  static const LinearGradient pinkGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF472B6), pink],
  );

  static const LinearGradient lilacGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [surfaceSoft, border],
  );

  static const LinearGradient softCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [surface, Color(0xFFF8FAFC)],
  );

  static List<BoxShadow> get panelShadow => const [
    BoxShadow(color: Color(0x0A000000), blurRadius: 16, offset: Offset(0, 4)),
  ];

  static List<BoxShadow> get darkPanelShadow => const [
    BoxShadow(color: Color(0x40000000), blurRadius: 16, offset: Offset(0, 4)),
  ];

  static Color flavorToneColor(FlavorTone tone) {
    return switch (tone) {
      FlavorTone.mint => accentDark,
      FlavorTone.sky => blue,
      FlavorTone.peach => orange,
      FlavorTone.lilac => pink,
    };
  }

  static Color flavorToneSoft(FlavorTone tone) {
    return switch (tone) {
      FlavorTone.mint => accentSoft,
      FlavorTone.sky => blueSoft,
      FlavorTone.peach => orangeSoft,
      FlavorTone.lilac => pinkSoft,
    };
  }

  static LinearGradient flavorToneGradient(FlavorTone tone) {
    return switch (tone) {
      FlavorTone.mint => accentGradient,
      FlavorTone.sky => blueGradient,
      FlavorTone.peach => orangeGradient,
      FlavorTone.lilac => pinkGradient,
    };
  }

  static BoxDecoration panelDecoration({
    Color? color,
    Gradient? gradient,
    double radius = 16,
    Color? borderColor,
    bool elevated = true,
  }) {
    return BoxDecoration(
      color: gradient == null ? (color ?? surface) : null,
      gradient: gradient,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor ?? border),
      boxShadow: elevated ? panelShadow : null,
    );
  }

  static ThemeData light({Color? seedColor}) {
    final effectivePrimary = seedColor ?? lightPrimary;
    final scheme = ColorScheme(
      brightness: Brightness.light,
      primary: effectivePrimary,
      onPrimary: lightButtonText,
      primaryContainer: lightBorder,
      onPrimaryContainer: lightPrimaryText,
      secondary: accentDark,
      onSecondary: Colors.white,
      secondaryContainer: accentSoft,
      onSecondaryContainer: accentDark,
      tertiary: blue,
      onTertiary: Colors.white,
      error: danger,
      onError: Colors.white,
      surface: lightSurface,
      onSurface: lightPrimaryText,
      onSurfaceVariant: lightSecondaryText,
      surfaceContainerLowest: lightBackground,
      surfaceContainerLow: const Color(0xFFF1F4F9),
      surfaceContainer: lightElevatedSurface,
      surfaceContainerHigh: const Color(0xFFE8EDF5),
      surfaceContainerHighest: const Color(0xFFE2E8F0),
      outline: lightBorder,
      outlineVariant: const Color(0xFFCBD5E1),
      shadow: Colors.black.withValues(alpha: 0.04),
      scrim: Colors.black.withValues(alpha: 0.3),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: lightBackground,
      canvasColor: lightBackground,
      splashFactory: InkRipple.splashFactory,
      extensions: const [
        AppColorsExtension.light,
        AppDecorationsExtension.light,
      ],
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 40,
          fontWeight: FontWeight.w800,
          color: lightPrimaryText,
          letterSpacing: -1.2,
          height: 1.05,
        ),
        displayMedium: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          color: lightPrimaryText,
          letterSpacing: -0.9,
          height: 1.1,
        ),
        displaySmall: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: lightPrimaryText,
          letterSpacing: -0.6,
        ),
        headlineLarge: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: lightPrimaryText,
          letterSpacing: -0.6,
          height: 1.14,
        ),
        headlineMedium: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: lightPrimaryText,
          letterSpacing: -0.4,
          height: 1.2,
        ),
        headlineSmall: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w700,
          color: lightPrimaryText,
          letterSpacing: -0.2,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: lightPrimaryText,
          letterSpacing: -0.2,
        ),
        titleMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: lightPrimaryText,
        ),
        titleSmall: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: lightPrimaryText,
        ),
        bodyLarge: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: lightPrimaryText,
          height: 1.45,
        ),
        bodyMedium: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: lightSecondaryText,
          height: 1.45,
        ),
        bodySmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w400,
          color: lightMutedText,
          height: 1.4,
        ),
        labelLarge: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: lightPrimaryText,
          letterSpacing: 0.2,
        ),
        labelMedium: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: lightPrimaryText,
          letterSpacing: 0.5,
        ),
        labelSmall: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: lightMutedText,
          letterSpacing: 1.1,
        ),
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: lightPrimaryText,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: lightSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: lightBorder),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: lightElevatedSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightSurface,
        labelStyle: const TextStyle(
          color: lightSecondaryText,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: const TextStyle(color: lightMutedText),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: effectivePrimary, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: danger, width: 1.6),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          shadowColor: Colors.transparent,
          backgroundColor: effectivePrimary,
          foregroundColor: lightButtonText,
          disabledBackgroundColor: lightSurface,
          disabledForegroundColor: lightMutedText,
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 50),
          side: const BorderSide(color: lightBorder),
          backgroundColor: lightElevatedSurface,
          foregroundColor: lightPrimaryText,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: effectivePrimary,
          foregroundColor: lightButtonText,
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: lightPrimaryText,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: lightPrimaryText,
          disabledForegroundColor: lightMutedText,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        iconColor: lightPrimaryText,
        textColor: lightPrimaryText,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: lightSurface,
        selectedColor: lightBorder,
        secondarySelectedColor: lightBorder,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: const BorderSide(color: lightBorder),
        ),
        side: const BorderSide(color: lightBorder),
        labelStyle: const TextStyle(
          color: lightPrimaryText,
          fontWeight: FontWeight.w700,
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: effectivePrimary,
        inactiveTrackColor: lightBorder,
        thumbColor: effectivePrimary,
        overlayColor: effectivePrimary.withValues(alpha: 0.12),
        trackHeight: 6,
      ),
      searchBarTheme: SearchBarThemeData(
        elevation: const WidgetStatePropertyAll(0),
        backgroundColor: const WidgetStatePropertyAll(lightSurface),
        side: const WidgetStatePropertyAll(BorderSide(color: lightBorder)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: lightBackground,
        indicatorColor: const Color(0xFFE8E8ED),
        height: 68,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            fontWeight: FontWeight.w700,
            color: states.contains(WidgetState.selected)
                ? lightPrimaryText
                : lightSecondaryText,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? lightPrimaryText
                : lightSecondaryText,
          );
        }),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: lightPrimaryText,
        unselectedLabelColor: lightSecondaryText,
        dividerColor: lightBorder,
        indicatorColor: effectivePrimary,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return lightSecondaryText;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return effectivePrimary;
          }
          return lightBorder;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        side: const BorderSide(color: lightBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: lightElevatedSurface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: effectivePrimary,
        foregroundColor: lightButtonText,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: effectivePrimary,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dividerColor: lightBorder,
    );
  }

  static ThemeData dark({Color? seedColor}) {
    final effectivePrimary = seedColor ?? darkPrimary;
    final scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: effectivePrimary,
      onPrimary: darkButtonText,
      primaryContainer: darkElevatedSurface,
      onPrimaryContainer: darkPrimaryText,
      secondary: accent,
      onSecondary: Colors.black,
      secondaryContainer: accentSoft,
      onSecondaryContainer: darkPrimaryText,
      tertiary: blue,
      onTertiary: Colors.black,
      error: danger,
      onError: Colors.black,
      surface: darkSurface,
      onSurface: darkPrimaryText,
      onSurfaceVariant: darkSecondaryText,
      surfaceContainerLowest: darkBackground,
      surfaceContainerLow: const Color(0xFF0F121A),
      surfaceContainer: darkSurface,
      surfaceContainerHigh: darkElevatedSurface,
      surfaceContainerHighest: const Color(0xFF222B3D),
      outline: darkBorder,
      outlineVariant: const Color(0xFF333E56),
      shadow: Colors.black.withValues(alpha: 0.6),
      scrim: Colors.black.withValues(alpha: 0.7),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: darkBackground,
      canvasColor: darkBackground,
      splashFactory: InkRipple.splashFactory,
      extensions: const [
        AppColorsExtension.dark,
        AppDecorationsExtension.dark,
      ],
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: darkPrimaryText,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: darkBorder),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: darkElevatedSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 40,
          fontWeight: FontWeight.w800,
          color: darkPrimaryText,
          letterSpacing: -1.2,
          height: 1.05,
        ),
        displayMedium: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          color: darkPrimaryText,
          letterSpacing: -0.9,
          height: 1.1,
        ),
        displaySmall: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: darkPrimaryText,
          letterSpacing: -0.6,
        ),
        headlineLarge: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: darkPrimaryText,
          letterSpacing: -0.6,
          height: 1.14,
        ),
        headlineMedium: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: darkPrimaryText,
          letterSpacing: -0.4,
          height: 1.2,
        ),
        headlineSmall: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w700,
          color: darkPrimaryText,
          letterSpacing: -0.2,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: darkPrimaryText,
          letterSpacing: -0.2,
        ),
        titleMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: darkPrimaryText,
        ),
        titleSmall: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: darkPrimaryText,
        ),
        bodyLarge: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: darkPrimaryText,
          height: 1.45,
        ),
        bodyMedium: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: darkSecondaryText,
          height: 1.45,
        ),
        bodySmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w400,
          color: darkMutedText,
          height: 1.4,
        ),
        labelLarge: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: darkPrimaryText,
          letterSpacing: 0.2,
        ),
        labelMedium: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: darkPrimaryText,
          letterSpacing: 0.5,
        ),
        labelSmall: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: darkMutedText,
          letterSpacing: 1.1,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        labelStyle: const TextStyle(
          color: darkSecondaryText,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: const TextStyle(color: darkMutedText),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: effectivePrimary, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: danger, width: 1.6),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          shadowColor: Colors.transparent,
          backgroundColor: effectivePrimary,
          foregroundColor: darkButtonText,
          disabledBackgroundColor: darkSurface,
          disabledForegroundColor: darkMutedText,
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 50),
          side: const BorderSide(color: darkBorder),
          backgroundColor: darkSurface,
          foregroundColor: darkPrimaryText,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: effectivePrimary,
          foregroundColor: darkButtonText,
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: darkPrimaryText,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: darkPrimaryText,
          disabledForegroundColor: darkMutedText,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        iconColor: darkPrimaryText,
        textColor: darkPrimaryText,
      ),
      searchBarTheme: SearchBarThemeData(
        elevation: const WidgetStatePropertyAll(0),
        backgroundColor: const WidgetStatePropertyAll(darkSurface),
        side: const WidgetStatePropertyAll(BorderSide(color: darkBorder)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: darkBackground,
        indicatorColor: darkElevatedSurface,
        height: 68,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            fontWeight: FontWeight.w700,
            color: states.contains(WidgetState.selected)
                ? darkPrimaryText
                : darkSecondaryText,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? darkPrimaryText
                : darkSecondaryText,
          );
        }),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: darkPrimaryText,
        unselectedLabelColor: darkSecondaryText,
        dividerColor: darkBorder,
        indicatorColor: effectivePrimary,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: darkElevatedSurface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: effectivePrimary,
        foregroundColor: darkButtonText,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: darkElevatedSurface,
        contentTextStyle: const TextStyle(
          color: darkPrimaryText,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dividerColor: darkBorder,
    );
  }
}
