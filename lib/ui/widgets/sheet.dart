import 'package:flutter/cupertino.dart';

import '../theme.dart';

/// Builds a sheet's content. [controller] belongs to the phone sheet's
/// drag-to-dismiss scrolling and is null for the desktop form panel.
typedef InsightSheetBuilder =
    Widget Function(BuildContext context, ScrollController? controller);

/// Presents a self-contained task: an iOS sheet on phones, and on wide
/// windows a centered form panel (the iPad and Mac convention) so a form
/// doesn't stretch across the whole screen.
///
/// The panel doesn't close on an outside click, so an edit in progress
/// isn't lost; the content provides Cancel.
Future<T?> showInsightSheet<T>(
  BuildContext context, {
  required InsightSheetBuilder builder,
}) {
  if (!InsightBreakpoints.usesSidebar(context)) {
    return showCupertinoSheet<T>(
      context: context,
      scrollableBuilder: (context, controller) => builder(context, controller),
    );
  }

  return Navigator.of(context, rootNavigator: true).push<T>(
    PageRouteBuilder<T>(
      opaque: false,
      barrierDismissible: false,
      barrierColor: const Color(0x59000000),
      transitionDuration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, _, _) => SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560, maxHeight: 760),
              child: DecoratedBox(
                decoration: const ShapeDecoration(
                  shape: RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.all(
                      Radius.circular(InsightRadii.sheet),
                    ),
                  ),
                  shadows: [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 40,
                      offset: Offset(0, 16),
                    ),
                  ],
                ),
                child: ClipRSuperellipse(
                  borderRadius: BorderRadius.circular(InsightRadii.sheet),
                  child: builder(context, null),
                ),
              ),
            ),
          ),
        ),
      ),
      transitionsBuilder: (context, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween(begin: 0.96, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    ),
  );
}
