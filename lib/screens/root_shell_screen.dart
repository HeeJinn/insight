import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../providers/router_provider.dart';

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

  bool _canPopRootNavigator() {
    final branchNavigator = _activeBranchNavigator();
    final branchCanPop = branchNavigator?.canPop() ?? false;
    return widget.navigationShell.currentIndex == 0 && !branchCanPop;
  }

  void _handleBackIntercept() {
    final branchNavigator = _activeBranchNavigator();
    if (branchNavigator != null && branchNavigator.canPop()) {
      branchNavigator.pop();
      return;
    }
    if (widget.navigationShell.currentIndex != 0) {
      widget.navigationShell.goBranch(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _canPopRootNavigator(),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackIntercept();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: widget.navigationShell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: widget.navigationShell.currentIndex,
          onDestinationSelected: _goToBranch,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.insights_outlined),
              selectedIcon: Icon(Icons.insights),
              label: 'Insights',
            ),
            NavigationDestination(
              icon: Icon(Icons.groups_outlined),
              selectedIcon: Icon(Icons.groups),
              label: 'Students',
            ),
            NavigationDestination(
              icon: Icon(Icons.schedule_outlined),
              selectedIcon: Icon(Icons.schedule),
              label: 'Sessions',
            ),
            NavigationDestination(
              icon: Icon(Icons.admin_panel_settings_outlined),
              selectedIcon: Icon(Icons.admin_panel_settings),
              label: 'Admin',
            ),
          ],
        ),
      ),
    );
  }
}
