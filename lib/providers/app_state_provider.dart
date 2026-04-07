import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _onboardingDoneKey = 'onboarding_done';
const _privacyAcceptedKey = 'privacy_accepted';

final onboardingDoneProvider = StateProvider<bool>((ref) => false);
final privacyAcceptedProvider = StateProvider<bool>((ref) => false);

final appStateBootstrapProvider = FutureProvider<void>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  ref.read(onboardingDoneProvider.notifier).state =
      prefs.getBool(_onboardingDoneKey) ?? false;
  ref.read(privacyAcceptedProvider.notifier).state =
      prefs.getBool(_privacyAcceptedKey) ?? false;
});

final appStateControllerProvider = Provider<AppStateController>((ref) {
  return AppStateController(ref);
});

class AppStateController {
  final Ref _ref;
  AppStateController(this._ref);

  Future<void> completeOnboarding({required bool acceptedPrivacy}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingDoneKey, true);
    await prefs.setBool(_privacyAcceptedKey, acceptedPrivacy);
    _ref.read(onboardingDoneProvider.notifier).state = true;
    _ref.read(privacyAcceptedProvider.notifier).state = acceptedPrivacy;
  }
}
