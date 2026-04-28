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

  static double navAwareBottomInset(BuildContext context, {double extra = 16}) {
    return MediaQuery.viewPaddingOf(context).bottom +
        kBottomNavigationBarHeight +
        extra;
  }
}

class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;

  static EdgeInsets pageSection({required bool compact}) {
    return EdgeInsets.all(compact ? sm : md);
  }

  static EdgeInsets panelPadding({required bool compact}) {
    return EdgeInsets.all(compact ? md : lg);
  }

  static double sectionGap(bool compact) => compact ? sm : md;

  static double contentGap(bool compact) => compact ? xs : sm;
}
