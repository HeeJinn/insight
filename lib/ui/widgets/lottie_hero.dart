// A Lottie hero for onboarding and empty states, from the
// ios-onboarding-lottie skill's template.
//
// Handles the details that separate a polished hero from a distracting one:
//  • plays once and holds the last frame (or loops, when asked)
//  • starts only when [active] is true, so carousel pages don't all play
//    off-screen at once
//  • shows the final frame when Reduce Motion is on
//  • falls back to a Cupertino symbol if the file is missing or invalid
//  • runtime recoloring for light/dark mode, by layer or by color
//  • a VoiceOver label, or none when the title already says it

import 'package:flutter/cupertino.dart';
import 'package:lottie/lottie.dart';

import '../theme.dart';

class LottieHero extends StatefulWidget {
  const LottieHero({
    super.key,
    required this.asset,
    required this.fallbackIcon,
    this.size = 160,
    this.loop = false,
    this.active = true,
    this.semanticLabel,
    this.recolor = const {},
    this.swapColors = const {},
    this.segment,
  });

  /// Path under assets/, e.g. 'assets/animations/welcome.json'. A `.lottie`
  /// archive also works (see [_decoder]).
  final String asset;

  /// Shown in the same slot if the animation can't load.
  final IconData fallbackIcon;

  final double size;

  /// Loop forever instead of playing once. Reserve for waiting states.
  final bool loop;

  /// Play only while true; restarts from the beginning each time it turns
  /// true. Pass `pageIndex == currentPage` inside a PageView.
  final bool active;

  /// What the animation shows, for VoiceOver. Null hides it from
  /// accessibility (use when the title already carries the meaning).
  final String? semanticLabel;

  /// Layer key paths to recolor, e.g. {'**.Fill 1': CupertinoColors.label}.
  /// Keys are dot-separated Lottie key paths; `**` matches any depth.
  /// Colors may be CupertinoDynamicColor and are resolved per brightness.
  final Map<String, Color> recolor;

  /// Replaces colors wherever they appear, for files whose layers aren't
  /// named (common in LottieFiles downloads, where [recolor] can't target
  /// anything). Keys are the file's original colors as 0xAARRGGBB values
  /// (ints, so the map can be const; Color keys can't be); values may be
  /// CupertinoDynamicColor, e.g. to lighten a dark outline only in dark mode:
  /// `swapColors: const {0xFF263238: myOutlineColor}`.
  final Map<int, Color> swapColors;

  /// Play only the part between two named markers, e.g. ('intro', 'intro').
  /// The first is the start marker, the second the end marker.
  final (String, String)? segment;

  @override
  State<LottieHero> createState() => _LottieHeroState();
}

class _LottieHeroState extends State<LottieHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);
  LottieComposition? _composition;
  double _from = 0;
  double _to = 1;

  bool get _reduceMotion => MediaQuery.disableAnimationsOf(context);

  @override
  void didUpdateWidget(LottieHero old) {
    super.didUpdateWidget(old);
    if (widget.active != old.active) _sync(restart: widget.active);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduce Motion can change while the screen is up.
    if (_composition != null) _sync(restart: false);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // The lottie package calls onLoaded from a microtask, after the build, so
  // setState here is safe.
  void _onLoaded(LottieComposition composition) {
    final segment = widget.segment;
    setState(() {
      _composition = composition;
      if (segment != null) {
        _from = composition.getMarker(segment.$1)?.start ?? 0;
        _to = composition.getMarker(segment.$2)?.end ?? 1;
      }
    });
    _controller.duration = composition.duration * (_to - _from).abs();
    _sync(restart: true);
  }

  /// Plays, loops, holds or resets the animation to match the widget's
  /// state and the Reduce Motion setting.
  void _sync({required bool restart}) {
    if (_composition == null) return;
    if (_reduceMotion) {
      _controller.stop();
      _controller.value = 1; // the final pose, no motion
      return;
    }
    if (!widget.active) {
      _controller.stop();
      return;
    }
    if (widget.loop) {
      _controller.repeat();
    } else if (restart || _controller.value == 0) {
      _controller.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    Color resolve(Color c) =>
        c is CupertinoDynamicColor ? c.resolveFrom(context) : c;

    // Compared as 8-bit ARGB: parsed Lottie colors are floats and rarely
    // equal a hex Color exactly.
    final swaps = {
      for (final e in widget.swapColors.entries) e.key: resolve(e.value),
    };
    Color swap(Color? original) {
      final c = original ?? const Color(0x00000000);
      return swaps[c.toARGB32()] ?? c;
    }

    // The callbacks receive the shape's original color as startValue. (The
    // frame-info type isn't exported by the package, so the closures stay
    // inline and let Dart infer it.)
    final values = [
      for (final entry in widget.recolor.entries)
        ValueDelegate.color(entry.key.split('.'), value: resolve(entry.value)),
      if (swaps.isNotEmpty) ...[
        ValueDelegate.color(const [
          '**',
        ], callback: (info) => swap(info.startValue)),
        ValueDelegate.strokeColor(const [
          '**',
        ], callback: (info) => swap(info.startValue)),
      ],
    ];

    final lottie = Lottie.asset(
      widget.asset,
      width: widget.size,
      height: widget.size,
      fit: BoxFit.contain,
      // The controller maps 0–1 onto the chosen segment.
      controller: _from == 0 && _to == 1
          ? _controller
          : _controller.drive(Tween(begin: _from, end: _to)),
      onLoaded: _onLoaded,
      decoder: widget.asset.endsWith('.lottie') ? _decoder : null,
      delegates: values.isEmpty ? null : LottieDelegates(values: values),
      errorBuilder: (context, error, stack) => SizedBox.square(
        dimension: widget.size,
        child: Icon(
          widget.fallbackIcon,
          size: widget.size * 0.5,
          color: InsightColors.accent.resolveFrom(context),
        ),
      ),
    );

    final label = widget.semanticLabel;
    return label == null
        ? ExcludeSemantics(child: lottie)
        : Semantics(image: true, label: label, child: lottie);
  }

  /// Picks the first animation out of a dotLottie (.lottie) archive.
  static Future<LottieComposition?> _decoder(List<int> bytes) {
    return LottieComposition.decodeZip(
      bytes,
      filePicker: (files) {
        for (final f in files) {
          if (f.name.startsWith('animations/') && f.name.endsWith('.json')) {
            return f;
          }
        }
        return null;
      },
    );
  }
}
