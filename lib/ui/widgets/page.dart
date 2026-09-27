import 'package:flutter/cupertino.dart';

import '../liquid_glass.dart';
import '../theme.dart';
import 'adaptive_shell.dart';

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
    final width = MediaQuery.sizeOf(context).width;
    final sidebar = InsightBreakpoints.usesSidebar(context);
    final paneWidth = sidebar ? width - AdaptiveShell.sidebarWidth : width;
    final margin = sidebar ? InsightSpacing.wideMargin : 0.0;
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

    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: [
          navBar,
          if (onRefresh != null)
            CupertinoSliverRefreshControl(onRefresh: onRefresh),
          for (final sliver in slivers)
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: side),
              sliver: sliver,
            ),
          SliverToBoxAdapter(
            child: SizedBox(height: AdaptiveShell.bottomInset(context) + 24),
          ),
        ],
      ),
    );
  }
}

/// The iOS 26 bar for a pushed screen: a chevron in a glass circle with no
/// "Back" text, and a centered title.
CupertinoNavigationBar insightPushedBar({
  required String title,
  Widget? trailing,
  VoidCallback? onBack,
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
          icon: CupertinoIcons.chevron_back,
          semanticLabel: 'Back',
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
