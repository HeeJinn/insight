import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insight/app_theme.dart';
import 'package:insight/models/flavor_profile.dart';

void main() {
  group('AppTheme & Extensions QA Tests', () {
    test('Light Theme has correct Apple-inspired color tokens', () {
      final theme = AppTheme.light();
      expect(theme.scaffoldBackgroundColor, const Color(0xFFFFFFFF));
      expect(theme.colorScheme.surface, const Color(0xFFF5F5F7));
      expect(theme.colorScheme.primary, const Color(0xFF1D1D1F));
      expect(theme.colorScheme.onPrimary, const Color(0xFFFFFFFF));
      expect(theme.dividerColor, const Color(0xFFE8E8ED));

      final colors = theme.extension<AppColorsExtension>();
      expect(colors, isNotNull);
      expect(colors!.background, const Color(0xFFFFFFFF));
      expect(colors.surface, const Color(0xFFF5F5F7));
      expect(colors.primaryText, const Color(0xFF1D1D1F));
      expect(colors.secondaryText, const Color(0xFF6E6E73));
      expect(colors.mutedText, const Color(0xFF86868B));
      expect(colors.border, const Color(0xFFE8E8ED));

      final decos = theme.extension<AppDecorationsExtension>();
      expect(decos, isNotNull);
      expect(decos!.cardRadius, 16.0);
      expect(decos.buttonRadius, 14.0);
    });

    test('Dark Theme has correct OLED Pure Black color tokens', () {
      final theme = AppTheme.dark();
      expect(theme.scaffoldBackgroundColor, const Color(0xFF000000));
      expect(theme.colorScheme.surface, const Color(0xFF1D1D1F));
      expect(theme.colorScheme.primary, const Color(0xFFF5F5F7));
      expect(theme.colorScheme.onPrimary, const Color(0xFF000000));
      expect(theme.dividerColor, const Color(0xFF38383A));

      final colors = theme.extension<AppColorsExtension>();
      expect(colors, isNotNull);
      expect(colors!.background, const Color(0xFF000000));
      expect(colors.surface, const Color(0xFF1D1D1F));
      expect(colors.elevatedSurface, const Color(0xFF2C2C2E));
      expect(colors.primaryText, const Color(0xFFF5F5F7));
      expect(colors.secondaryText, const Color(0xFFA1A1A6));
      expect(colors.mutedText, const Color(0xFF86868B));
      expect(colors.border, const Color(0xFF38383A));

      final decos = theme.extension<AppDecorationsExtension>();
      expect(decos, isNotNull);
      expect(decos!.cardRadius, 16.0);
      expect(decos.buttonRadius, 14.0);
    });

    test('Dynamic seedColor correctly tints Light and Dark themes', () {
      const customSeed = Color(0xFF2563EB); // Sky Blue
      final lightTheme = AppTheme.light(seedColor: customSeed);
      final darkTheme = AppTheme.dark(seedColor: customSeed);

      expect(lightTheme.colorScheme.primary, customSeed);
      expect(darkTheme.colorScheme.primary, customSeed);
    });

    test('FlavorTone colors are consistent', () {
      expect(AppTheme.flavorToneColor(FlavorTone.mint), AppTheme.accentDark);
      expect(AppTheme.flavorToneColor(FlavorTone.sky), AppTheme.blue);
      expect(AppTheme.flavorToneColor(FlavorTone.peach), AppTheme.orange);
      expect(AppTheme.flavorToneColor(FlavorTone.lilac), AppTheme.pink);
    });
  });
}
