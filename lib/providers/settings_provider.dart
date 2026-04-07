import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

final recognitionThresholdProvider = StateProvider<double>((ref) => 0.70);

enum AppThemePreference { system, light, dark }

const _themePrefKey = 'theme_preference';
const _thresholdKey = 'recognition_threshold';
const _animationsKey = 'animations_enabled';
const _soundKey = 'sound_feedback_enabled';
const _compactKey = 'compact_mode_enabled';

final themePreferenceProvider = StateProvider<AppThemePreference>(
  (ref) => AppThemePreference.system,
);
final animationsEnabledProvider = StateProvider<bool>((ref) => true);
final soundFeedbackProvider = StateProvider<bool>((ref) => true);
final compactModeProvider = StateProvider<bool>((ref) => false);

final settingsBootstrapProvider = FutureProvider<void>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final rawTheme = prefs.getString(_themePrefKey) ?? AppThemePreference.system.name;
  final theme = AppThemePreference.values.firstWhere(
    (v) => v.name == rawTheme,
    orElse: () => AppThemePreference.system,
  );
  ref.read(themePreferenceProvider.notifier).state = theme;
  ref.read(recognitionThresholdProvider.notifier).state =
      prefs.getDouble(_thresholdKey) ?? 0.70;
  ref.read(animationsEnabledProvider.notifier).state = prefs.getBool(_animationsKey) ?? true;
  ref.read(soundFeedbackProvider.notifier).state = prefs.getBool(_soundKey) ?? true;
  ref.read(compactModeProvider.notifier).state = prefs.getBool(_compactKey) ?? false;
});

final effectiveThemeModeProvider = Provider<ThemeMode>((ref) {
  final pref = ref.watch(themePreferenceProvider);
  return switch (pref) {
    AppThemePreference.light => ThemeMode.light,
    AppThemePreference.dark => ThemeMode.dark,
    AppThemePreference.system => ThemeMode.system,
  };
});

final settingsControllerProvider = Provider<SettingsController>(
  (ref) => SettingsController(ref),
);

class SettingsController {
  final Ref _ref;
  SettingsController(this._ref);

  Future<void> setThemePreference(AppThemePreference value) async {
    _ref.read(themePreferenceProvider.notifier).state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themePrefKey, value.name);
  }

  Future<void> setRecognitionThreshold(double value) async {
    _ref.read(recognitionThresholdProvider.notifier).state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_thresholdKey, value);
  }

  Future<void> setAnimationsEnabled(bool value) async {
    _ref.read(animationsEnabledProvider.notifier).state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_animationsKey, value);
  }

  Future<void> setSoundFeedback(bool value) async {
    _ref.read(soundFeedbackProvider.notifier).state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_soundKey, value);
  }

  Future<void> setCompactMode(bool value) async {
    _ref.read(compactModeProvider.notifier).state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_compactKey, value);
  }
}
