import 'package:flutter/cupertino.dart';

import '../liquid_glass.dart';
import '../theme.dart';

/// A root admin screen: a left-aligned large title that collapses on
/// scroll, optional search beneath it, and content kept to a readable
/// width on wide windows. Leaves room for the floating tab bar on phones.
class InsightRootPage extends StatelessWidget {
  const InsightRootPage({
    super.key,
    required this.title,
    required this.slivers,
    this.leading,
    this.trailing,
    this.searchField,
    this.onRefresh,
    this.maxContentWidth = 1100,
  });

  final String title;
  final List<Widget> slivers;
  final Widget? leading;
  final Widget? trailing;
  final CupertinoSearchTextField? searchField;
  final Future<void> Function()? onRefresh;
  final double maxContentWidth;

  @override
  Widget build(BuildContext context) {
    // Measured, not taken from the window, so the page also works as one
    // column of a list–detail layout.
    return LayoutBuilder(
      builder: (context, constraints) => _build(context, constraints.maxWidth),
    );
  }

  Widget _build(BuildContext context, double paneWidth) {
    final sidebar = InsightBreakpoints.usesSidebar(context);
    final margin = !sidebar
        ? 0.0
        : paneWidth >= 700
        ? InsightSpacing.wideMargin
        : 8.0;
    final side = paneWidth > maxContentWidth + margin * 2
        ? (paneWidth - maxContentWidth) / 2
        : margin;

    final navBar = searchField != null
        ? CupertinoSliverNavigationBar.search(
            largeTitle: Text(title),
            leading: leading,
            trailing: trailing,
            border: null,
            searchField: searchField!,
          )
        : CupertinoSliverNavigationBar(
            largeTitle: Text(title),
            leading: leading,
            trailing: trailing,
            border: null,
          );

    // The sliver bar drops its large title in landscape, as an iPhone does
    // on its side. Desktop and tablet windows are landscape too but have
    // room for it, so present the bar as portrait there. Its safe-area
    // padding also carries the page's side margin, so the title lines up
    // with the content below.
    final mq = MediaQuery.of(context);
    final keepLargeTitle = mq.size.shortestSide >= 600;
    final bar = MediaQuery(
      data: mq.copyWith(
        size: keepLargeTitle && mq.orientation == Orientation.landscape
            ? Size(mq.size.width, mq.size.width + 1)
            : mq.size,
        padding: mq.padding.copyWith(
          left: mq.padding.left + side,
          right: mq.padding.right + side,
        ),
      ),
      child: navBar,
    );

    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: [
          bar,
          if (onRefresh != null)
            CupertinoSliverRefreshControl(onRefresh: onRefresh),
          for (final sliver in slivers)
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: side),
              sliver: sliver,
            ),
          SliverToBoxAdapter(
            // Includes the floating tab bar on phones (see AdaptiveShell).
            child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 24),
          ),
        ],
      ),
    );
  }
}

/// The iOS 26 bar for a pushed screen: a chevron in a glass circle with no
/// "Back" text, and a centered title. [modal] screens (opened full screen
/// over the app) get an xmark instead.
CupertinoNavigationBar insightPushedBar({
  required String title,
  Widget? trailing,
  VoidCallback? onBack,
  bool modal = false,
}) {
  return CupertinoNavigationBar(
    automaticallyImplyLeading: false,
    border: null,
    backgroundColor: const Color(0x00000000),
    padding: const EdgeInsetsDirectional.symmetric(horizontal: 12),
    leading: Builder(
      builder: (context) => Align(
        widthFactor: 1,
        child: GlassIconButton(
          icon: modal ? CupertinoIcons.xmark : CupertinoIcons.chevron_back,
          semanticLabel: modal ? 'Close' : 'Back',
          size: 40,
          onPressed: onBack ?? () => Navigator.of(context).maybePop(),
        ),
      ),
    ),
    middle: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
    trailing: trailing,
  );
}

/// A sliver wrapper for a group of rows or cards with an optional header
/// in the iOS 26 content-heading style (sentence case, bold).
class InsightSectionHeader extends StatelessWidget {
  const InsightSectionHeader(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Text(
              text,
              style: InsightText.title3.copyWith(
                fontWeight: FontWeight.w700,
                color: InsightColors.label.resolveFrom(context),
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
