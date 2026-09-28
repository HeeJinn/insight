import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'glass_tab_bar.dart';
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

  /// The glass bar stops widening here, so it stays a capsule on tablets
  /// in portrait rather than a strip across the screen.
  static const double _tabBarMaxWidth = 520;

  bool get _usesCommandKey =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

  /// The phone layout: sections full-height, the glass tab bar floating over
  /// them. The bar's height and gap are added to the bottom safe-area
  /// padding, so any screen that respects `MediaQuery.padding.bottom`
  /// scrolls its last row clear of the bar with no per-screen numbers.
  Widget _withTabBar(BuildContext context) {
    final media = MediaQuery.of(context);
    final tabIndexes = [
      for (var i = 0; i < destinations.length; i++)
        if (destinations[i].inTabBar) i,
    ];
    // Destinations outside the bar (Settings, opened from Today) keep the
    // tab they were reached from highlighted.
    final selected = tabIndexes.indexOf(currentIndex);

    return Stack(
      children: [
        MediaQuery(
          data: media.copyWith(
            padding: media.padding.copyWith(
              bottom:
                  media.padding.bottom +
                  GlassTabBar.height +
                  GlassTabBar.bottomGap,
            ),
          ),
          child: child,
        ),
        Positioned(
          left: GlassTabBar.sideInset,
          right: GlassTabBar.sideInset,
          bottom: media.padding.bottom + GlassTabBar.bottomGap,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _tabBarMaxWidth),
              child: GlassTabBar(
                tabs: [
                  for (final i in tabIndexes)
                    GlassTab(
                      label: destinations[i].label,
                      icon: destinations[i].icon,
                      activeIcon: destinations[i].selectedIcon,
                    ),
                ],
                currentIndex: selected < 0 ? 0 : selected,
                onTap: (i) => onSelect(tabIndexes[i]),
              ),
            ),
          ),
        ),
      ],
    );
  }

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
        : _withTabBar(context);

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
