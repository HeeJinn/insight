import 'package:flutter/material.dart';

import '../../app_theme.dart';

/// A search field matching iOS's native search-bar interaction: a fully
/// rounded pill with the icon+hint centered as one unit while idle (exactly
/// like the collapsed system search bar), which shifts to a left-aligned
/// editable field with a sliding "Cancel" action once you tap in or start
/// typing. Replaces ad hoc uses of Material's `SearchBar` (which brings its
/// own background/shape/elevation, easily fighting an outer container) or a
/// hand-styled `TextField` per screen.
class AppSearchField extends StatefulWidget {
  final String hintText;
  final ValueChanged<String> onChanged;
  final String? initialValue;
  final VoidCallback? onCancel;

  const AppSearchField({
    super.key,
    required this.onChanged,
    this.hintText = 'Search',
    this.initialValue,
    this.onCancel,
  });

  @override
  State<AppSearchField> createState() => _AppSearchFieldState();
}

class _AppSearchFieldState extends State<AppSearchField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _isFocused = false;

  bool get _isActive => _isFocused || _controller.text.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue)
      ..addListener(() => setState(() {}));
    _focusNode = FocusNode()..addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    setState(() => _isFocused = _focusNode.hasFocus);
  }

  void _clear() {
    _controller.clear();
    widget.onChanged('');
  }

  void _cancel() {
    _controller.clear();
    widget.onChanged('');
    _focusNode.unfocus();
    widget.onCancel?.call();
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.appColors.accent;
    final active = _isActive;

    return Row(
      children: [
        Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            height: 44,
            decoration: BoxDecoration(
              color: context.appColors.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: _isFocused ? accent : context.appColors.border,
                width: _isFocused ? 1.4 : 0.8,
              ),
              boxShadow: _isFocused
                  ? [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.16),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => _focusNode.requestFocus(),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Idle state: icon + hint centered as one unit, exactly like
                  // the collapsed native iOS search bar. Purely decorative
                  // (IgnorePointer) — the tap lands on the real field beneath.
                  IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: active ? 0 : 1,
                      duration: const Duration(milliseconds: 140),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.search_rounded,
                            size: 18,
                            color: context.appColors.mutedText,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            widget.hintText,
                            style: AppleTypography.body.copyWith(
                              color: context.appColors.mutedText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Active state: left-aligned icon + editable field + clear.
                  Row(
                    children: [
                      const SizedBox(width: 12),
                      Icon(
                        Icons.search_rounded,
                        size: 18,
                        color: active ? accent : Colors.transparent,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Opacity(
                          opacity: active ? 1 : 0,
                          child: TextField(
                            controller: _controller,
                            focusNode: _focusNode,
                            onChanged: widget.onChanged,
                            style: AppleTypography.body.copyWith(
                              color: context.appColors.primaryText,
                            ),
                            cursorColor: accent,
                            decoration: const InputDecoration(
                              isCollapsed: true,
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ),
                      if (_controller.text.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: GestureDetector(
                            onTap: _clear,
                            child: Container(
                              width: 20,
                              height: 20,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: context.appColors.mutedText.withValues(
                                  alpha: 0.18,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.close_rounded,
                                size: 13,
                                color: context.appColors.mutedText,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(width: 12),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        ClipRect(
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            alignment: Alignment.centerLeft,
            widthFactor: active ? 1 : 0,
            child: Padding(
              padding: const EdgeInsets.only(left: 10),
              child: GestureDetector(
                onTap: _cancel,
                behavior: HitTestBehavior.opaque,
                child: Text(
                  'Cancel',
                  style: AppleTypography.body.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
