import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show
        DefaultMaterialLocalizations,
        Material,
        MaterialType,
        ScaffoldMessenger,
        Theme;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_theme.dart';
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
      localizationsDelegates: const [
        DefaultMaterialLocalizations.delegate,
        DefaultCupertinoLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      builder: (context, child) => _MaterialBridge(child: child!),
    );
  }
}

/// Keeps screens that still use Material widgets working under
/// `CupertinoApp` while they are rebuilt: a Material theme matched to the
/// current brightness, a messenger for their snackbars, and a transparent
/// Material for ink. Remove once no screen needs it.
class _MaterialBridge extends ConsumerWidget {
  const _MaterialBridge({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final seed = ref.watch(activeThemeSeedProvider);
    return Theme(
      data: dark
          ? AppTheme.dark(seedColor: seed)
          : AppTheme.light(seedColor: seed),
      child: ScaffoldMessenger(
        child: Material(type: MaterialType.transparency, child: child),
      ),
    );
  }
}
