import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ui/theme.dart';

const _adminPinKey = 'admin_pin_v1';

/// The admin PIN, or null until one is created. Loaded by
/// [adminLockBootstrapProvider].
///
/// Stored in shared preferences on the kiosk machine. It keeps students at
/// the door out of the admin area; it is not meant to resist someone with
/// access to the computer's files.
final adminPinProvider = StateProvider<String?>((ref) => null);

/// Whether the admin area is open. On desktop the app opens locked into the
/// kiosk; phones and tablets have no kiosk-first flow, so they start
/// unlocked.
final adminUnlockedProvider = StateProvider<bool>((ref) => !isDesktopPlatform);

final adminLockBootstrapProvider = FutureProvider<void>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  ref.read(adminPinProvider.notifier).state = prefs.getString(_adminPinKey);
});

final adminLockControllerProvider = Provider<AdminLockController>(
  (ref) => AdminLockController(ref),
);

class AdminLockController {
  AdminLockController(this._ref);
  final Ref _ref;

  bool get hasPin => _ref.read(adminPinProvider) != null;

  /// Unlocks when [pin] matches. Returns whether it did.
  bool tryUnlock(String pin) {
    final ok = pin == _ref.read(adminPinProvider);
    if (ok) _ref.read(adminUnlockedProvider.notifier).state = true;
    return ok;
  }

  Future<void> setPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_adminPinKey, pin);
    _ref.read(adminPinProvider.notifier).state = pin;
  }

  void unlock() => _ref.read(adminUnlockedProvider.notifier).state = true;

  /// Closes the admin area. Only meaningful on desktop, where the kiosk is
  /// the default screen.
  void lock() {
    if (isDesktopPlatform) {
      _ref.read(adminUnlockedProvider.notifier).state = false;
    }
  }
}
