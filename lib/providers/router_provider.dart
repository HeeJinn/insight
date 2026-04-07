import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../screens/home_screen.dart';
import '../screens/admin_dashboard.dart';
import '../screens/kiosk_mode.dart';
import '../screens/settings_screen.dart';
import '../screens/insights_screen.dart';
import '../screens/sessions_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/privacy_policy_screen.dart';
import '../screens/insight_logs_screen.dart';

// Define routes
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminDashboard(),
      ),
      GoRoute(
        path: '/kiosk',
        builder: (context, state) => const KioskMode(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/insights',
        builder: (context, state) => const InsightsScreen(),
      ),
      GoRoute(
        path: '/sessions',
        builder: (context, state) => const SessionsScreen(),
      ),
      GoRoute(
        path: '/insights/logs',
        builder: (context, state) => const InsightLogsScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/privacy',
        builder: (context, state) => const PrivacyPolicyScreen(),
      ),
    ],
  );
});
