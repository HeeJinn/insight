// The floating iOS 26 glass tab bar, from the ios-glass-tab-bar skill.
// AdaptiveShell floats it over the admin sections on phone-width layouts.
// Keep the numbers (spring curve, 420 ms platter, 150 ms icon swap, 64 pt
// height, 10.5 pt labels): they are what make it feel native. The surface
// is Insight's LiquidGlass rather than the skill's GlassSurface, so every
// piece of glass in the app is the same material.
//
// What makes it feel native:
// - a frosted capsule that floats over the content (content blurs through);
// - a soft accent-tinted platter that springs, with a little overshoot, to
//   the selected tab;
// - the selected icon swaps outline -> filled with a quick scale + fade, and
//   its label goes bold;
// - a selection haptic only when the tab actually changes.

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../liquid_glass.dart';

/// One destination in [GlassTabBar].
class GlassTab {
  const GlassTab({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });

  /// One short word: "Today", "Sales", "More".
  final String label;

  /// Outline, for tabs that aren't selected.
  final IconData icon;

  /// Filled, for the selected tab.
  final IconData activeIcon;
}

/// A floating glass tab bar in the style of iOS 26: a frosted capsule over
/// the content (light glass in light mode, dark glass in dark mode), every
/// tab an icon with its label beneath, and a soft glass platter that springs
/// across to the selected tab.
class GlassTabBar extends StatelessWidget {
  const GlassTabBar({
    super.key,
    required this.tabs,
    required this.currentIndex,
    required this.onTap,
    this.accent,
    this.inactive,
  });

  final List<GlassTab> tabs;
  final int currentIndex;
  final ValueChanged<int> onTap;

  /// The selected tab's glyph, label and platter. Defaults to the
  /// CupertinoTheme's primary color.
  final Color? accent;

  /// Unselected glyphs and labels. Defaults to secondaryLabel.
  final Color? inactive;

  /// The capsule's height; screens keep this much clear at the bottom.
  static const height = 64.0;

  /// Gap between the capsule and the bottom safe area.
  static const bottomGap = 4.0;

  /// Inset from the screen's sides.
  static const sideInset = 20.0;

  /// A gentle overshoot, like the system bar's selection.
  static const _spring = Cubic(0.34, 1.3, 0.5, 1);

  @override
  Widget build(BuildContext context) {
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final tint = accent ?? CupertinoTheme.of(context).primaryColor;
    final muted =
        inactive ?? CupertinoColors.secondaryLabel.resolveFrom(context);
    // The selected tab's platter: a wash of the app's color, as iOS 26
    // tints the selected tab with it.
    final platter = tint.withValues(alpha: dark ? 0.22 : 0.12);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    // Insight's own Liquid Glass, so the bar matches the glass buttons in
    // the navigation bars and the kiosk's status capsule.
    return LiquidGlass(
      child: Container(
        height: height,
        padding: const EdgeInsets.all(4),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final slot = constraints.maxWidth / tabs.length;
            return Stack(
              children: [
                AnimatedPositioned(
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 420),
                  curve: _spring,
                  left: slot * currentIndex,
                  top: 0,
                  bottom: 0,
                  width: slot,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: platter,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (var i = 0; i < tabs.length; i++)
                      Expanded(
                        child: _TabItem(
                          tab: tabs[i],
                          selected: i == currentIndex,
                          color: i == currentIndex ? tint : muted,
                          onTap: () => onTap(i),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.tab,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final GlassTab tab;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  static const _fast = Duration(milliseconds: 150);

  @override
  Widget build(BuildContext context) {
    final base = CupertinoTheme.of(context).textTheme.textStyle;

    return Semantics(
      button: true,
      selected: selected,
      label: tab.label,
      excludeSemantics: true,
      child: GestureDetector(
        key: ValueKey('tab-${tab.label}'),
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (!selected) HapticFeedback.selectionClick();
          onTap();
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: _fast,
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: Tween(begin: 0.8, end: 1.0).animate(animation),
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: Icon(
                selected ? tab.activeIcon : tab.icon,
                key: ValueKey(selected),
                size: 23,
                color: color,
              ),
            ),
            const SizedBox(height: 3),
            // iOS doesn't grow tab labels with Dynamic Type; the bar's height
            // is fixed, so neither do we.
            MediaQuery.withNoTextScaling(
              child: AnimatedDefaultTextStyle(
                duration: _fast,
                style: base.copyWith(
                  fontSize: 10.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: 0.1,
                  color: color,
                ),
                child: Text(
                  tab.label,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  softWrap: false,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
