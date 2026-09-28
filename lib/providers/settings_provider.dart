import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/session_entry.dart';
import '../services/face_processor.dart';

final recognitionThresholdProvider = StateProvider<double>(
  (ref) => FaceProcessor.defaultThreshold,
);

enum AppThemePreference { system, light, dark }

const _themePrefKey = 'theme_preference';
// v2: thresholds saved for the old pipeline (0.35-1.20 scale) are not
// meaningful for aligned MobileFaceNet embeddings, so they are ignored.
const _thresholdKey = 'recognition_threshold_v2';
const _soundKey = 'sound_feedback_enabled';
const _lateDefaultKey = 'default_late_after_minutes';

final themePreferenceProvider = StateProvider<AppThemePreference>(
  (ref) => AppThemePreference.system,
);
final soundFeedbackProvider = StateProvider<bool>((ref) => true);

/// The late cutoff new sessions start with, in minutes after the start.
final defaultLateAfterProvider = StateProvider<int>(
  (ref) => SessionEntry.defaultLateAfterMinutes,
);

final settingsBootstrapProvider = FutureProvider<void>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final rawTheme =
      prefs.getString(_themePrefKey) ?? AppThemePreference.system.name;
  final theme = AppThemePreference.values.firstWhere(
    (v) => v.name == rawTheme,
    orElse: () => AppThemePreference.system,
  );
  ref.read(themePreferenceProvider.notifier).state = theme;
  ref.read(recognitionThresholdProvider.notifier).state =
      prefs.getDouble(_thresholdKey) ?? FaceProcessor.defaultThreshold;
  ref.read(soundFeedbackProvider.notifier).state =
      prefs.getBool(_soundKey) ?? true;
  ref.read(defaultLateAfterProvider.notifier).state =
      prefs.getInt(_lateDefaultKey) ?? SessionEntry.defaultLateAfterMinutes;
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

  Future<void> setSoundFeedback(bool value) async {
    _ref.read(soundFeedbackProvider.notifier).state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_soundKey, value);
  }

  Future<void> setDefaultLateAfter(int minutes) async {
    _ref.read(defaultLateAfterProvider.notifier).state = minutes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lateDefaultKey, minutes);
  }
}
