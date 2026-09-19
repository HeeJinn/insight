import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_theme.dart';

class DockDestination {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const DockDestination({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

/// A compact floating dock, sized to its content rather than stretched
/// edge-to-edge: inactive destinations are icon-only, and the active one
/// expands into a colored capsule revealing its label. This keeps items
/// close together at any window width instead of spreading out into a
/// sparse, evenly-stretched bar.
class AppDock extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final List<DockDestination> destinations;

  const AppDock({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
    required this.destinations,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dockBg = isDark ? const Color(0xE61C1C1E) : const Color(0xF2FFFFFF);
    final borderColor = context.appColors.border;

    return SafeArea(
      top: false,
      left: false,
      right: false,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Center(
          heightFactor: 1.0,
          child: Container(
            decoration: BoxDecoration(
              color: dockBg,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: borderColor, width: 0.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.1),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(destinations.length, (index) {
                final isSelected = index == selectedIndex;
                final destination = destinations[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: _DockItem(
                    destination: destination,
                    isSelected: isSelected,
                    onTap: () {
                      if (!isSelected) {
                        HapticFeedback.lightImpact();
                        onSelect(index);
                      }
                    },
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _DockItem extends StatefulWidget {
  final DockDestination destination;
  final bool isSelected;
  final VoidCallback onTap;

  const _DockItem({
    required this.destination,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_DockItem> createState() => _DockItemState();
}

class _DockItemState extends State<_DockItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isSelected = widget.isSelected;
    final activeColor = colors.accent;
    final inactiveColor = colors.mutedText;

    return Semantics(
      selected: isSelected,
      button: true,
      label: widget.destination.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _pressController.forward(),
        onTapUp: (_) => _pressController.reverse(),
        onTapCancel: () => _pressController.reverse(),
        onTap: widget.onTap,
        child: ScaleTransition(
          scale: _scale,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            height: 46,
            padding: EdgeInsets.symmetric(
              horizontal: isSelected ? 16 : 13,
            ),
            decoration: BoxDecoration(
              color: isSelected ? activeColor : Colors.transparent,
              borderRadius: BorderRadius.circular(23),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, animation) => ScaleTransition(
                    scale: animation,
                    child: FadeTransition(opacity: animation, child: child),
                  ),
                  child: Icon(
                    isSelected
                        ? widget.destination.activeIcon
                        : widget.destination.icon,
                    key: ValueKey(isSelected),
                    size: 21,
                    color: isSelected ? Colors.white : inactiveColor,
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.centerLeft,
                  child: isSelected
                      ? Padding(
                          padding: const EdgeInsets.only(left: 7),
                          child: Text(
                            widget.destination.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.1,
                              color: Colors.white,
                            ),
                          ),
                        )
                      : const SizedBox(width: 0, height: 0),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
