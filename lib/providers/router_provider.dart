import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/admin_lock_provider.dart';
import '../providers/app_state_provider.dart';
import '../screens/admin_shell_screen.dart';
import '../screens/home_screen.dart';
import '../screens/insight_logs_screen.dart';
import '../screens/insights_screen.dart';
import '../screens/kiosk_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/privacy_policy_screen.dart';
import '../screens/sessions_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/students_screen.dart';
import '../ui/theme.dart';

final todayNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'today');
final attendanceNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'attendance');
final studentsNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'students');
final sessionsNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'sessions');
final reportsNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'reports');
final settingsNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'settings');

/// Where the app lands once onboarding is done: the kiosk on the Mac or PC
/// at the door, the admin area on phones and tablets.
String get homeLocation => isDesktopPlatform ? '/kiosk' : '/admin/today';

/// Paths from before the restructure, kept so older links still resolve.
const _legacyRedirects = {
  '/students': '/admin/students',
  '/sessions': '/admin/sessions',
  '/insights': '/admin/reports',
  '/insights/logs': '/admin/attendance',
  '/admin': '/admin/today',
  '/settings': '/admin/settings',
  '/settings/privacy': '/privacy',
};

class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    ref.listen(onboardingDoneProvider, (_, _) => notifyListeners());
    ref.listen(adminUnlockedProvider, (_, _) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _RouterRefreshNotifier(ref);
  ref.onDispose(refreshNotifier.dispose);

  GoRoute section(String path, Widget screen) => GoRoute(
        path: path,
        pageBuilder: (context, state) => NoTransitionPage(child: screen),
      );

  return GoRouter(
    initialLocation: homeLocation,
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final location = state.matchedLocation;
      final legacy = _legacyRedirects[location];
      if (legacy != null) return legacy;

      final onboardingDone = ref.read(onboardingDoneProvider);
      final isOnboarding = location == '/onboarding';
      final isPrivacy = location == '/privacy';
      if (!onboardingDone) {
        return isOnboarding || isPrivacy ? null : '/onboarding';
      }
      if (isOnboarding || location == '/') return homeLocation;

      if (location.startsWith('/admin') && !ref.read(adminUnlockedProvider)) {
        return '/kiosk';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', redirect: (_, _) => homeLocation),
      GoRoute(path: '/kiosk', builder: (_, _) => const KioskScreen()),
      GoRoute(
        path: '/onboarding',
        builder: (_, _) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/privacy',
        builder: (_, _) => const PrivacyPolicyScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AdminShellScreen(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            navigatorKey: todayNavigatorKey,
            routes: [section('/admin/today', const HomeScreen())],
          ),
          StatefulShellBranch(
            navigatorKey: attendanceNavigatorKey,
            routes: [
              section('/admin/attendance', const InsightLogsScreen()),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: studentsNavigatorKey,
            routes: [section('/admin/students', const StudentsScreen())],
          ),
          StatefulShellBranch(
            navigatorKey: sessionsNavigatorKey,
            routes: [section('/admin/sessions', const SessionsScreen())],
          ),
          StatefulShellBranch(
            navigatorKey: reportsNavigatorKey,
            routes: [section('/admin/reports', const InsightsScreen())],
          ),
          StatefulShellBranch(
            navigatorKey: settingsNavigatorKey,
            routes: [
              section('/admin/settings', const SettingsScreen()),
            ],
          ),
        ],
      ),
    ],
  );
});
