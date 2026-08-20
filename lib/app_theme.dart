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

  static const AppColorsExtension light = AppColorsExtension(
    background: Color(0xFFFFFFFF),
    surface: Color(0xFFF5F5F7),
    elevatedSurface: Color(0xFFFFFFFF),
    primary: Color(0xFF1D1D1F),
    primaryText: Color(0xFF1D1D1F),
    secondaryText: Color(0xFF6E6E73),
    mutedText: Color(0xFF86868B),
    border: Color(0xFFE8E8ED),
    button: Color(0xFF1D1D1F),
    buttonText: Color(0xFFFFFFFF),
    accent: Color(0xFF6366F1),
    accentDark: Color(0xFF4F46E5),
    accentSoft: Color(0xFFE8E9FF),
    blue: Color(0xFF2563EB),
    blueSoft: Color(0xFFEFF6FF),
    orange: Color(0xFFF97316),
    orangeSoft: Color(0xFFFFF7ED),
    pink: Color(0xFFEC4899),
    pinkSoft: Color(0xFFFDF2F8),
    lilac: Color(0xFFF5F3FF),
    success: Color(0xFF22C55E),
    successSoft: Color(0xFFDCFCE7),
    danger: Color(0xFFEF4444),
    dangerSoft: Color(0xFFFEE2E2),
    warning: Color(0xFFF59E0B),
    warningSoft: Color(0xFFFEF3C7),
  );

  static const AppColorsExtension dark = AppColorsExtension(
    background: Color(0xFF000000),
    surface: Color(0xFF1D1D1F),
    elevatedSurface: Color(0xFF2C2C2E),
    primary: Color(0xFFF5F5F7),
    primaryText: Color(0xFFF5F5F7),
    secondaryText: Color(0xFFA1A1A6),
    mutedText: Color(0xFF86868B),
    border: Color(0xFF38383A),
    button: Color(0xFFF5F5F7),
    buttonText: Color(0xFF000000),
    accent: Color(0xFF818CF8),
    accentDark: Color(0xFF6366F1),
    accentSoft: Color(0xFF1E1B4B),
    blue: Color(0xFF60A5FA),
    blueSoft: Color(0xFF172554),
    orange: Color(0xFFFB923C),
    orangeSoft: Color(0xFF431407),
    pink: Color(0xFFF472B6),
    pinkSoft: Color(0xFF500724),
    lilac: Color(0xFF2E1065),
    success: Color(0xFF4ADE80),
    successSoft: Color(0xFF052E16),
    danger: Color(0xFFF87171),
    dangerSoft: Color(0xFF450A0A),
    warning: Color(0xFFFBBF24),
    warningSoft: Color(0xFF451A03),
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
  static const Color lightBackground = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFF5F5F7);
  static const Color lightElevatedSurface = Color(0xFFFFFFFF);
  static const Color lightPrimary = Color(0xFF1D1D1F);
  static const Color lightPrimaryText = Color(0xFF1D1D1F);
  static const Color lightSecondaryText = Color(0xFF6E6E73);
  static const Color lightMutedText = Color(0xFF86868B);
  static const Color lightBorder = Color(0xFFE8E8ED);
  static const Color lightButton = Color(0xFF1D1D1F);
  static const Color lightButtonText = Color(0xFFFFFFFF);

  // Dark mode palette
  static const Color darkBackground = Color(0xFF000000);
  static const Color darkSurface = Color(0xFF1D1D1F);
  static const Color darkElevatedSurface = Color(0xFF2C2C2E);
  static const Color darkPrimary = Color(0xFFF5F5F7);
  static const Color darkPrimaryText = Color(0xFFF5F5F7);
  static const Color darkSecondaryText = Color(0xFFA1A1A6);
  static const Color darkMutedText = Color(0xFF86868B);
  static const Color darkBorder = Color(0xFF38383A);
  static const Color darkButton = Color(0xFFF5F5F7);
  static const Color darkButtonText = Color(0xFF000000);

  // Semantic fallbacks for static backward compatibility
  static const Color background = lightBackground;
  static const Color backgroundSoft = lightSurface;
  static const Color surface = lightSurface;
  static const Color surfaceSoft = Color(0xFFEAEAEF);
  static const Color ink = lightPrimaryText;
  static const Color muted = lightMutedText;
  static const Color border = lightBorder;

  static const Color accent = Color(0xFF6366F1);
  static const Color accentDark = Color(0xFF4F46E5);
  static const Color accentSoft = Color(0xFFE8E9FF);

  static const Color blue = Color(0xFF2563EB);
  static const Color blueSoft = Color(0xFFEFF6FF);
  static const Color orange = Color(0xFFF97316);
  static const Color orangeSoft = Color(0xFFFFF7ED);
  static const Color pink = Color(0xFFEC4899);
  static const Color pinkSoft = Color(0xFFFDF2F8);
  static const Color lilac = Color(0xFFF5F3FF);
  static const Color success = Color(0xFF22C55E);
  static const Color danger = Color(0xFFEF4444);
  static const Color dangerSoft = Color(0xFFFEE2E2);
  static const Color warningSoft = Color(0xFFFFF3D6);

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
      surfaceContainerLow: lightSurface,
      surfaceContainer: lightSurface,
      surfaceContainerHigh: lightElevatedSurface,
      surfaceContainerHighest: const Color(0xFFEAEAEF),
      outline: lightBorder,
      outlineVariant: const Color(0xFFD6D6DC),
      shadow: Colors.black.withValues(alpha: 0.05),
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
          fontWeight: FontWeight.w700,
          color: lightPrimaryText,
          height: 1.08,
          inherit: true,
        ),
        displayMedium: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: lightPrimaryText,
          height: 1.1,
          inherit: true,
        ),
        displaySmall: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: lightPrimaryText,
          inherit: true,
        ),
        headlineLarge: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: lightPrimaryText,
          height: 1.14,
          inherit: true,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: lightPrimaryText,
          height: 1.2,
          inherit: true,
        ),
        headlineSmall: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: lightPrimaryText,
          inherit: true,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: lightPrimaryText,
          inherit: true,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: lightPrimaryText,
          inherit: true,
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: lightPrimaryText,
          inherit: true,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: lightPrimaryText,
          height: 1.45,
          inherit: true,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: lightSecondaryText,
          height: 1.45,
          inherit: true,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: lightMutedText,
          height: 1.4,
          inherit: true,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: lightPrimaryText,
          inherit: true,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: lightPrimaryText,
          inherit: true,
        ),
        labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: lightMutedText,
          inherit: true,
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
      surfaceContainerLow: darkSurface,
      surfaceContainer: darkSurface,
      surfaceContainerHigh: darkElevatedSurface,
      surfaceContainerHighest: const Color(0xFF3A3A3C),
      outline: darkBorder,
      outlineVariant: const Color(0xFF48484A),
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
          fontWeight: FontWeight.w700,
          color: darkPrimaryText,
          height: 1.08,
          inherit: true,
        ),
        displayMedium: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: darkPrimaryText,
          height: 1.1,
          inherit: true,
        ),
        displaySmall: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: darkPrimaryText,
          inherit: true,
        ),
        headlineLarge: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: darkPrimaryText,
          height: 1.14,
          inherit: true,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: darkPrimaryText,
          height: 1.2,
          inherit: true,
        ),
        headlineSmall: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: darkPrimaryText,
          inherit: true,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: darkPrimaryText,
          inherit: true,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: darkPrimaryText,
          inherit: true,
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: darkPrimaryText,
          inherit: true,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: darkPrimaryText,
          height: 1.45,
          inherit: true,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: darkSecondaryText,
          height: 1.45,
          inherit: true,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: darkMutedText,
          height: 1.4,
          inherit: true,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: darkPrimaryText,
          inherit: true,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: darkPrimaryText,
          inherit: true,
        ),
        labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: darkMutedText,
          inherit: true,
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
