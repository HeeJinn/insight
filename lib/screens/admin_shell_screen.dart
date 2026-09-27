import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/admin_lock_provider.dart';
import '../providers/router_provider.dart';
import '../ui/insight_ui.dart';

/// Frames the admin sections: sidebar on wide windows, floating tab bar on
/// phones. Each section keeps its own navigation stack.
class AdminShellScreen extends ConsumerWidget {
  const AdminShellScreen({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const destinations = [
    ShellDestination(
      icon: CupertinoIcons.sun_max,
      selectedIcon: CupertinoIcons.sun_max_fill,
      label: 'Today',
    ),
    ShellDestination(
      icon: CupertinoIcons.checkmark_seal,
      selectedIcon: CupertinoIcons.checkmark_seal_fill,
      label: 'Attendance',
    ),
    ShellDestination(
      icon: CupertinoIcons.person_2,
      selectedIcon: CupertinoIcons.person_2_fill,
      label: 'Students',
    ),
    ShellDestination(
      icon: CupertinoIcons.calendar,
      selectedIcon: CupertinoIcons.calendar_today,
      label: 'Sessions',
    ),
    ShellDestination(
      icon: CupertinoIcons.chart_bar,
      selectedIcon: CupertinoIcons.chart_bar_fill,
      label: 'Reports',
    ),
    ShellDestination(
      icon: CupertinoIcons.gear,
      selectedIcon: CupertinoIcons.gear_solid,
      label: 'Settings',
      inTabBar: false,
    ),
  ];

  void _select(int index) {
    final again = index == navigationShell.currentIndex;
    // Tapping the current section again returns it to its first screen.
    // Details pushed straight onto the section's navigator (a student, a
    // sheet's route) aren't go_router routes, so pop those explicitly too.
    if (again) {
      branchNavigatorKeys[index].currentState?.popUntil(
        (route) => route.isFirst,
      );
    }
    navigationShell.goBranch(index, initialLocation: again);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (navigationShell.currentIndex != 0) {
          navigationShell.goBranch(0);
        } else if (isDesktopPlatform) {
          startKiosk(context, ref);
        } else {
          SystemNavigator.pop();
        }
      },
      child: AdaptiveShell(
        destinations: destinations,
        currentIndex: navigationShell.currentIndex,
        onSelect: _select,
        sidebarFooter: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoButton.filled(
            sizeStyle: CupertinoButtonSize.medium,
            borderRadius: BorderRadius.circular(InsightRadii.capsule),
            onPressed: () => startKiosk(context, ref),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CupertinoIcons.viewfinder, size: 18),
                SizedBox(width: 8),
                // Truncates rather than overflows at large text sizes.
                Flexible(
                  child: Text(
                    'Start Kiosk',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        child: navigationShell,
      ),
    );
  }
}

/// Leaves the admin area for the kiosk and locks it behind the PIN again.
void startKiosk(BuildContext context, WidgetRef ref) {
  HapticFeedback.mediumImpact();
  ref.read(adminLockControllerProvider).lock();
  context.go('/kiosk');
}
