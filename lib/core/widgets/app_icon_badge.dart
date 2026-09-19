import 'package:flutter/material.dart';

/// The tinted rounded-square icon badge used throughout list rows and
/// summary panels (student directory, sessions, insights metrics, admin
/// overview). Centralizes a pattern that was previously copy-pasted with
/// slightly different sizes across screens.
class AppIconBadge extends StatelessWidget {
  final IconData icon;
  final Color tint;
  final double size;
  final double iconSize;

  const AppIconBadge({
    super.key,
    required this.icon,
    required this.tint,
    this.size = 30,
    this.iconSize = 17,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(size * 0.23),
      ),
      child: Icon(icon, size: iconSize, color: tint),
    );
  }
}
