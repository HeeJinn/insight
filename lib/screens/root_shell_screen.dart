import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../providers/router_provider.dart';
import '../widgets/app_dock.dart';

class RootShellScreen extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const RootShellScreen({super.key, required this.navigationShell});

  @override
  State<RootShellScreen> createState() => _RootShellScreenState();
}

class _RootShellScreenState extends State<RootShellScreen> {
  void _goToBranch(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  NavigatorState? _activeBranchNavigator() {
    return switch (widget.navigationShell.currentIndex) {
      0 => homeBranchNavigatorKey.currentState,
      1 => insightsBranchNavigatorKey.currentState,
      2 => studentsBranchNavigatorKey.currentState,
      3 => sessionsBranchNavigatorKey.currentState,
      _ => adminBranchNavigatorKey.currentState,
    };
  }

  Future<void> _handleBackIntercept() async {
    final branchNavigator = _activeBranchNavigator();
    if (branchNavigator != null && branchNavigator.canPop()) {
      branchNavigator.pop();
      return;
    }
    if (widget.navigationShell.currentIndex != 0) {
      widget.navigationShell.goBranch(0);
      return;
    }

    final shouldExit =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Exit Insight?'),
            content: const Text('Do you want to close Insight now?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Exit'),
              ),
            ],
          ),
        ) ??
        false;

    if (shouldExit) {
      await SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackIntercept();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: widget.navigationShell,
        bottomNavigationBar: AppDock(
          selectedIndex: widget.navigationShell.currentIndex,
          onSelect: _goToBranch,
          destinations: const [
            DockDestination(
              icon: Icons.dashboard_outlined,
              activeIcon: Icons.dashboard_rounded,
              label: 'Command',
            ),
            DockDestination(
              icon: Icons.query_stats_outlined,
              activeIcon: Icons.query_stats_rounded,
              label: 'Telemetry',
            ),
            DockDestination(
              icon: Icons.badge_outlined,
              activeIcon: Icons.badge_rounded,
              label: 'Students',
            ),
            DockDestination(
              icon: Icons.timer_outlined,
              activeIcon: Icons.timer_rounded,
              label: 'Sessions',
            ),
            DockDestination(
              icon: Icons.tune_outlined,
              activeIcon: Icons.tune_rounded,
              label: 'Admin',
            ),
          ],
        ),
      ),
    );
  }
}
