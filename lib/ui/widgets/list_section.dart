import 'package:flutter/cupertino.dart';

import '../theme.dart';

/// An iOS 26 inset-grouped section: sentence-case header, one rounded card
/// holding the rows, hairline separators inset to where the text starts,
/// and an optional footnote.
///
/// Flutter's `CupertinoListSection.insetGrouped` hard-codes the pre-26
/// 10pt radius and its own outer margins; this one uses the app radius and
/// leaves horizontal placement to the page.
class InsightListSection extends StatelessWidget {
  const InsightListSection({
    super.key,
    required this.children,
    this.header,
    this.headerTrailing,
    this.footer,
    this.dividerInset = 60,
    this.margin = const EdgeInsets.symmetric(horizontal: 16),
  });

  final List<Widget> children;
  final String? header;
  final Widget? headerTrailing;
  final String? footer;

  /// Where separators start, measured from the card's leading edge. 60
  /// clears a 29pt leading badge; use 16 for rows without a leading icon.
  final double dividerInset;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final secondary = InsightColors.secondaryLabel.resolveFrom(context);
    final separator = InsightColors.separator.resolveFrom(context);
    final radius = BorderRadius.circular(InsightRadii.section);

    return Padding(
      padding: margin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (header != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
              // A fixed height keeps side-by-side headers level whether or
              // not one has a trailing button.
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      header!,
                      style: InsightText.title3.copyWith(
                        fontWeight: FontWeight.w700,
                        color: InsightColors.label.resolveFrom(context),
                      ),
                    ),
                  ),
                  SizedBox(height: 32, child: headerTrailing),
                ],
              ),
            )
          else
            const SizedBox(height: 16),
          ClipRSuperellipse(
            borderRadius: radius,
            child: ColoredBox(
              color: InsightColors.card.resolveFrom(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0)
                      Padding(
                        padding: EdgeInsetsDirectional.only(
                          start: dividerInset,
                        ),
                        child: Container(height: 0.5, color: separator),
                      ),
                    children[i],
                  ],
                ],
              ),
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                footer!,
                style: InsightText.footnote.copyWith(color: secondary),
              ),
            ),
        ],
      ),
    );
  }
}

/// A standard list row: optional leading symbol, title with an optional
/// subtitle, a secondary trailing value, and a chevron when it drills in.
/// Highlights on press and hover.
class InsightRow extends StatefulWidget {
  const InsightRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.value,
    this.trailing,
    this.onTap,
    this.showChevron,
    this.selected = false,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;

  /// Secondary-colored text before the chevron.
  final String? value;

  /// Replaces [value] when a richer trailing widget is needed.
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Defaults to showing a chevron whenever the row is tappable.
  final bool? showChevron;

  /// Marks the row whose detail is showing beside the list.
  final bool selected;

  @override
  State<InsightRow> createState() => _InsightRowState();
}

class _InsightRowState extends State<InsightRow> {
  bool _pressed = false;
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final label = InsightColors.label.resolveFrom(context);
    final secondary = InsightColors.secondaryLabel.resolveFrom(context);
    final tertiary = InsightColors.tertiaryLabel.resolveFrom(context);
    final tappable = widget.onTap != null;
    final chevron = widget.showChevron ?? tappable;

    final Color background;
    if (widget.selected) {
      background = InsightColors.accent
          .resolveFrom(context)
          .withValues(alpha: 0.14);
    } else if (tappable && _pressed) {
      background = CupertinoColors.systemFill.resolveFrom(context);
    } else if (tappable && _hover) {
      background = InsightColors.fill.resolveFrom(context);
    } else {
      background = const Color(0x00000000);
    }

    final row = Container(
      color: background,
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 14, 10),
      child: LayoutBuilder(
        builder: (context, c) {
          // The trailing value keeps its natural width up to a cap, so it
          // sits flush right yet truncates before crowding out the title.
          final trailingCap = BoxConstraints(maxWidth: c.maxWidth * 0.45);
          return Row(
            children: [
              if (widget.leading != null) ...[
                widget.leading!,
                const SizedBox(width: 15),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: InsightText.body.copyWith(color: label),
                    ),
                    if (widget.subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Text(
                          widget.subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: InsightText.subheadline.copyWith(
                            color: secondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (widget.trailing != null) ...[
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: trailingCap,
                  child: widget.trailing!,
                ),
              ] else if (widget.value != null) ...[
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: trailingCap,
                  child: Text(
                    widget.value!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: InsightText.body.copyWith(
                      color: secondary,
                      fontFeatures: InsightText.tabular,
                    ),
                  ),
                ),
              ],
              if (chevron) ...[
                const SizedBox(width: 6),
                Icon(CupertinoIcons.chevron_forward, size: 17, color: tertiary),
              ],
            ],
          );
        },
      ),
    );

    if (!tappable) return row;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: row,
      ),
    );
  }
}
