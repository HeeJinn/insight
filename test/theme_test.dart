import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insight/app_theme.dart';
import 'package:insight/models/flavor_profile.dart';

void main() {
  group('AppTheme & Extensions QA Tests', () {
    test('Light Theme has correct precision instrument color tokens', () {
      final theme = AppTheme.light();
      expect(theme.scaffoldBackgroundColor, const Color(0xFFF8F9FA));
      expect(theme.colorScheme.surface, const Color(0xFFFFFFFF));
      expect(theme.colorScheme.primary, const Color(0xFF0F172A));
      expect(theme.colorScheme.onPrimary, const Color(0xFFFFFFFF));
      expect(theme.dividerColor, const Color(0xFFE2E8F0));

      final colors = theme.extension<AppColorsExtension>();
      expect(colors, isNotNull);
      expect(colors!.background, const Color(0xFFF8F9FA));
      expect(colors.surface, const Color(0xFFFFFFFF));
      expect(colors.primaryText, const Color(0xFF0F172A));
      expect(colors.secondaryText, const Color(0xFF475569));
      expect(colors.mutedText, const Color(0xFF94A3B8));
      expect(colors.border, const Color(0xFFE2E8F0));

      final decos = theme.extension<AppDecorationsExtension>();
      expect(decos, isNotNull);
      expect(decos!.cardRadius, 16.0);
      expect(decos.buttonRadius, 14.0);
    });

    test('Dark Theme has correct carbon-slate precision color tokens', () {
      final theme = AppTheme.dark();
      expect(theme.scaffoldBackgroundColor, const Color(0xFF0A0C10));
      expect(theme.colorScheme.surface, const Color(0xFF121620));
      expect(theme.colorScheme.primary, const Color(0xFFF8FAFC));
      expect(theme.colorScheme.onPrimary, const Color(0xFF0A0C10));
      expect(theme.dividerColor, const Color(0xFF242C3D));

      final colors = theme.extension<AppColorsExtension>();
      expect(colors, isNotNull);
      expect(colors!.background, const Color(0xFF0A0C10));
      expect(colors.surface, const Color(0xFF121620));
      expect(colors.elevatedSurface, const Color(0xFF181E2C));
      expect(colors.primaryText, const Color(0xFFF8FAFC));
      expect(colors.secondaryText, const Color(0xFF94A3B8));
      expect(colors.mutedText, const Color(0xFF64748B));
      expect(colors.border, const Color(0xFF242C3D));

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
