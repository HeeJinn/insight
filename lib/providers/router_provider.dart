import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import '../providers/app_state_provider.dart';
import '../screens/home_screen.dart';
import '../screens/admin_dashboard.dart';
import '../screens/kiosk_mode.dart';
import '../screens/settings_screen.dart';
import '../screens/insights_screen.dart';
import '../screens/sessions_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/privacy_policy_screen.dart';
import '../screens/insight_logs_screen.dart';
import '../screens/students_screen.dart';
import '../screens/flavor_studio_screen.dart';
import '../screens/root_shell_screen.dart';

// Define routes
final homeBranchNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'homeBranchNavigator',
);
final insightsBranchNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'insightsBranchNavigator',
);
final studentsBranchNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'studentsBranchNavigator',
);
final sessionsBranchNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'sessionsBranchNavigator',
);
final adminBranchNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'adminBranchNavigator',
);

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    redirect: (context, state) {
      final onboardingDone = ref.read(onboardingDoneProvider);
      final isOnboarding = state.matchedLocation == '/onboarding';
      if (!onboardingDone && !isOnboarding) {
        return '/onboarding';
      }
      if (onboardingDone && isOnboarding) {
        return '/';
      }
      return null;
    },
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            RootShellScreen(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            navigatorKey: homeBranchNavigatorKey,
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: insightsBranchNavigatorKey,
            routes: [
              GoRoute(
                path: '/insights',
                builder: (context, state) => const InsightsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: studentsBranchNavigatorKey,
            routes: [
              GoRoute(
                path: '/students',
                builder: (context, state) => const StudentsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: sessionsBranchNavigatorKey,
            routes: [
              GoRoute(
                path: '/sessions',
                builder: (context, state) => const SessionsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: adminBranchNavigatorKey,
            routes: [
              GoRoute(
                path: '/admin',
                builder: (context, state) => const AdminDashboard(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(path: '/kiosk', builder: (context, state) => const KioskMode()),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/settings/privacy',
        builder: (context, state) => const PrivacyPolicyScreen(),
      ),
      GoRoute(
        path: '/settings/flavors',
        builder: (context, state) => const FlavorStudioScreen(),
      ),
      GoRoute(
        path: '/insights/logs',
        builder: (context, state) => const InsightLogsScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(path: '/privacy', redirect: (_, __) => '/settings/privacy'),
      GoRoute(path: '/flavors', redirect: (_, __) => '/settings/flavors'),
    ],
  );
});
