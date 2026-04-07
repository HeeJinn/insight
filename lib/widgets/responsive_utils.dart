import 'package:flutter/material.dart';

class AppBreakpoints {
  static const double compact = 720;
  static const double medium = 1040;
  static const double large = 1320;

  static bool isCompact(double width) => width < compact;
  static bool isMedium(double width) => width >= compact && width < medium;
  static bool isLarge(double width) => width >= medium;
  static bool isTablet(double width) => width >= compact && width < large;
  static bool isDesktop(double width) => width >= medium;

  static double contentWidth(double width) {
    if (width >= 1500) {
      return 1320;
    }
    if (width >= 1240) {
      return 1180;
    }
    if (width >= medium) {
      return 920;
    }
    return width;
  }

  static EdgeInsets pagePadding(double width) {
    if (width >= 1240) {
      return const EdgeInsets.fromLTRB(34, 28, 34, 36);
    }
    if (width >= compact) {
      return const EdgeInsets.fromLTRB(24, 22, 24, 30);
    }
    return const EdgeInsets.fromLTRB(16, 16, 16, 24);
  }
}
