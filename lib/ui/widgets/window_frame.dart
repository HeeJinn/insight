import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';

import '../theme.dart';

/// Sets up the desktop window before the first frame: a resizable window
/// with the native title bar hidden, since [DesktopWindowFrame] draws its
/// own. Does nothing on phones and the web.
Future<void> configureDesktopWindow() async {
  if (!isDesktopPlatform) return;
  await windowManager.ensureInitialized();
  await windowManager.waitUntilReadyToShow(
    const WindowOptions(
      title: 'Insight',
      size: Size(1280, 800),
      // Narrow windows switch to the phone layout, so they can go small.
      minimumSize: Size(420, 600),
      center: true,
      titleBarStyle: TitleBarStyle.hidden,
    ),
    () async {
      await windowManager.show();
      await windowManager.focus();
    },
  );
}

/// The desktop window's title bar, drawn by the app so it blends into the
/// content: no title or icon, a strip you can drag to move the window
/// (double-click to maximize), and on Windows the standard minimize,
/// maximize and close buttons. On a Mac the system keeps its traffic lights
/// at the top left.
///
/// The bar's height is added to `MediaQuery.padding.top`, like a status bar,
/// so navigation bars and safe areas start below it while backgrounds (the
/// sidebar, the page) run up behind it.
class DesktopWindowFrame extends StatefulWidget {
  const DesktopWindowFrame({super.key, required this.child});

  final Widget child;

  /// Matches each system's own title bar height.
  static double heightFor(TargetPlatform platform) =>
      platform == TargetPlatform.macOS ? 28 : 32;

  @override
  State<DesktopWindowFrame> createState() => _DesktopWindowFrameState();
}

class _DesktopWindowFrameState extends State<DesktopWindowFrame>
    with WindowListener {
  bool _maximized = false;

  @override
  void initState() {
    super.initState();
    if (!isDesktopPlatform) return;
    windowManager.addListener(this);
    windowManager.isMaximized().then((value) {
      if (mounted) setState(() => _maximized = value);
    });
  }

  @override
  void dispose() {
    if (isDesktopPlatform) windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() => setState(() => _maximized = true);

  @override
  void onWindowUnmaximize() => setState(() => _maximized = false);

  @override
  Widget build(BuildContext context) {
    if (!isDesktopPlatform) return widget.child;

    final mac = defaultTargetPlatform == TargetPlatform.macOS;
    final height = DesktopWindowFrame.heightFor(defaultTargetPlatform);
    final brightness = CupertinoTheme.brightnessOf(context);
    final media = MediaQuery.of(context);

    return Stack(
      children: [
        MediaQuery(
          data: media.copyWith(
            padding: media.padding.copyWith(top: media.padding.top + height),
            viewPadding: media.viewPadding.copyWith(
              top: media.viewPadding.top + height,
            ),
          ),
          child: widget.child,
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: height,
          child: Row(
            children: [
              // The Mac's traffic lights draw themselves over this corner.
              const Expanded(child: DragToMoveArea(child: SizedBox.expand())),
              if (!mac) ...[
                WindowCaptionButton.minimize(
                  brightness: brightness,
                  onPressed: windowManager.minimize,
                ),
                if (_maximized)
                  WindowCaptionButton.unmaximize(
                    brightness: brightness,
                    onPressed: windowManager.unmaximize,
                  )
                else
                  WindowCaptionButton.maximize(
                    brightness: brightness,
                    onPressed: windowManager.maximize,
                  ),
                WindowCaptionButton.close(
                  brightness: brightness,
                  onPressed: windowManager.close,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
