import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../liquid_glass.dart';
import '../theme.dart';

class ShellDestination {
  const ShellDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.inTabBar = true,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;

  /// Whether this destination also appears in the phone tab bar. The tab
  /// bar holds at most five; the rest are reached from a screen's toolbar.
  final bool inTabBar;
}

/// The admin area's frame. Wide windows get a macOS-style source-list
/// sidebar; narrow ones get the iOS 26 floating glass tab bar over the
/// content.
class AdaptiveShell extends StatelessWidget {
  const AdaptiveShell({
    super.key,
    required this.destinations,
    required this.currentIndex,
    required this.onSelect,
    required this.child,
    this.sidebarFooter,
  });

  final List<ShellDestination> destinations;
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final Widget child;

  /// Pinned under the sidebar's list, e.g. the Start Kiosk button.
  final Widget? sidebarFooter;

  static const double sidebarWidth = 248;
  static const double _tabBarHeight = 62;

  /// Space a root screen must leave at its bottom so the last row scrolls
  /// clear of the floating tab bar and the home indicator.
  static double bottomInset(BuildContext context) {
    if (InsightBreakpoints.usesSidebar(context)) return 0;
    return _tabBarHeight + 12 + MediaQuery.paddingOf(context).bottom;
  }

  bool get _usesCommandKey =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

  @override
  Widget build(BuildContext context) {
    final sidebar = InsightBreakpoints.usesSidebar(context);

    // ⌘1…⌘n (Ctrl on Windows) switches sections.
    final shortcuts = <ShortcutActivator, VoidCallback>{
      for (var i = 0; i < destinations.length && i < 9; i++)
        SingleActivator(
          LogicalKeyboardKey(LogicalKeyboardKey.digit1.keyId + i),
          meta: _usesCommandKey,
          control: !_usesCommandKey,
        ): () =>
            onSelect(i),
    };

    final body = sidebar
        ? Row(
            children: [
              _Sidebar(
                destinations: destinations,
                currentIndex: currentIndex,
                onSelect: onSelect,
                footer: sidebarFooter,
              ),
              Container(
                width: 0.5,
                color: InsightColors.separator.resolveFrom(context),
              ),
              Expanded(child: child),
            ],
          )
        : Stack(
            children: [
              Positioned.fill(child: child),
              Align(
                alignment: Alignment.bottomCenter,
                child: _FloatingTabBar(
                  destinations: destinations,
                  currentIndex: currentIndex,
                  onSelect: onSelect,
                ),
              ),
            ],
          );

    return CallbackShortcuts(
      bindings: shortcuts,
      child: Focus(autofocus: true, child: body),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.destinations,
    required this.currentIndex,
    required this.onSelect,
    this.footer,
  });

  final List<ShellDestination> destinations;
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return Container(
      width: AdaptiveShell.sidebarWidth,
      color: InsightColors.sidebar.resolveFrom(context),
      padding: EdgeInsets.fromLTRB(12, topInset + 20, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 20),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: InsightColors.accent.resolveFrom(context),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    CupertinoIcons.viewfinder,
                    size: 18,
                    color: CupertinoColors.white,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Insight',
                  style: InsightText.headline.copyWith(
                    color: InsightColors.label.resolveFrom(context),
                  ),
                ),
              ],
            ),
          ),
          for (var i = 0; i < destinations.length; i++)
            _SidebarItem(
              destination: destinations[i],
              selected: i == currentIndex,
              onTap: () => onSelect(i),
            ),
          const Spacer(),
          ?footer,
        ],
      ),
    );
  }
}

class _SidebarItem extends StatefulWidget {
  const _SidebarItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final ShellDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final accent = InsightColors.accent.resolveFrom(context);
    final ink = InsightColors.label.resolveFrom(context);
    final selected = widget.selected;

    final Color background;
    if (selected) {
      background = accent.withValues(alpha: 0.14);
    } else if (_hover) {
      background = InsightColors.fill.resolveFrom(context);
    } else {
      background = const Color(0x00000000);
    }

    return Semantics(
      button: true,
      selected: selected,
      label: widget.destination.label,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.selectionClick();
            widget.onTap();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 36,
            margin: const EdgeInsets.only(bottom: 2),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  selected
                      ? widget.destination.selectedIcon
                      : widget.destination.icon,
                  size: 19,
                  color: selected ? accent : ink.withValues(alpha: 0.75),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.destination.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: InsightText.subheadline.copyWith(
                      color: selected ? accent : ink,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FloatingTabBar extends StatelessWidget {
  const _FloatingTabBar({
    required this.destinations,
    required this.currentIndex,
    required this.onSelect,
  });

  final List<ShellDestination> destinations;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final accent = InsightColors.accent.resolveFrom(context);
    final muted = InsightColors.secondaryLabel.resolveFrom(context);
    final items = [
      for (var i = 0; i < destinations.length; i++)
        if (destinations[i].inTabBar) i,
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.paddingOf(context).bottom + 8,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: LiquidGlass(
          child: SizedBox(
            height: AdaptiveShell._tabBarHeight,
            child: Row(
              children: [
                for (final i in items)
                  Expanded(
                    child: Semantics(
                      selected: i == currentIndex,
                      button: true,
                      label: destinations[i].label,
                      excludeSemantics: true,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          onSelect(i);
                        },
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              destinations[i].selectedIcon,
                              size: 24,
                              color: i == currentIndex ? accent : muted,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              destinations[i].label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: InsightText.caption2.copyWith(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: i == currentIndex ? accent : muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
