import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/admin_lock_provider.dart';
import 'providers/app_state_provider.dart';
import 'providers/router_provider.dart';
import 'providers/settings_provider.dart';
import 'services/demo_seed.dart';
import 'ui/insight_ui.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: InsightApp()));
}

class InsightApp extends ConsumerWidget {
  const InsightApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch every bootstrap before combining, so they load in parallel.
    final bootstraps = [
      ref.watch(settingsBootstrapProvider),
      ref.watch(appStateBootstrapProvider),
      ref.watch(adminLockBootstrapProvider),
      if (demoSeedEnabled) ref.watch(demoSeedProvider),
    ];
    final ready = bootstraps.every((b) => !b.isLoading);

    final brightness = switch (ref.watch(themePreferenceProvider)) {
      AppThemePreference.light => Brightness.light,
      AppThemePreference.dark => Brightness.dark,
      AppThemePreference.system => null,
    };
    final theme = insightCupertinoTheme(brightness: brightness);

    if (!ready) {
      // Preferences load from local storage in a few milliseconds; show the
      // plain page rather than a spinner.
      return CupertinoApp(
        debugShowCheckedModeBanner: false,
        theme: theme,
        home: const CupertinoPageScaffold(child: SizedBox.expand()),
      );
    }

    return CupertinoApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Insight',
      theme: theme,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
