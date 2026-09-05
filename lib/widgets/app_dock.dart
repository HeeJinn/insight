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
    final dockBg = isDark
        ? const Color(0xE6121620)
        : const Color(0xF2FFFFFF);
    final borderColor = isDark
        ? const Color(0x332E394E)
        : const Color(0x33000000);

    return SafeArea(
      top: false,
      left: false,
      right: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: dockBg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: borderColor, width: 0.9),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Row(
            children: List.generate(destinations.length, (index) {
              final isSelected = index == selectedIndex;
              final destination = destinations[index];
              return Expanded(
                child: _DockItem(
                  destination: destination,
                  isSelected: isSelected,
                  onTap: () {
                    if (!isSelected) {
                      HapticFeedback.selectionClick();
                    }
                    onSelect(index);
                  },
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _DockItem extends StatelessWidget {
  final DockDestination destination;
  final bool isSelected;
  final VoidCallback onTap;

  const _DockItem({
    required this.destination,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeBg = colors.accent.withValues(alpha: isDark ? 0.18 : 0.12);
    final activeColor = colors.accent;
    final inactiveColor = colors.mutedText;

    return Semantics(
      selected: isSelected,
      button: true,
      label: destination.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: activeColor.withValues(alpha: 0.1),
        highlightColor: Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: isSelected ? activeBg : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: isSelected
                ? Border.all(
                    color: activeColor.withValues(alpha: isDark ? 0.28 : 0.2),
                    width: 0.8,
                  )
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSelected ? destination.activeIcon : destination.icon,
                size: 20,
                color: isSelected ? activeColor : inactiveColor,
              ),
              const SizedBox(height: 3),
              Text(
                destination.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: isSelected ? 0.2 : 0.0,
                  color: isSelected ? activeColor : inactiveColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
