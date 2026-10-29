import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/context_extensions.dart';
import 'bar_title.dart';
import 'bottom_bar_frame.dart';
import 'page_bar.dart';

enum PageBackground { plain, gradient }

class AppScaffold extends StatefulWidget {
  const AppScaffold({
    super.key,
    required this.title,
    required this.slivers,
    this.largeTitle,
    this.cover,
    this.isTall = false,
    this.titleLine,
    this.leading,
    this.showBack = true,
    this.isTitleShown = true,
    this.actions = const [],
    this.background = PageBackground.plain,
    this.bottomBar,
    this.bottomBarFollowsKeyboard = true,
    this.controller,
    this.bottomPadding = 24,
    this.barTitle,
    this.refreshSliver,
    this.physics,
    this.scrollKey,
  });

  final String title;
  final List<Widget> slivers;

  final Widget? largeTitle;

  /// Fills the top of the page under the status bar, in place of the space
  /// for the bar, and scrolls with it.
  final Widget? cover;

  final bool isTall;

  final Widget? titleLine;

  /// Replaces the back button.
  final Widget? leading;
  final bool showBack;
  final bool isTitleShown;
  final List<Widget> actions;
  final PageBackground background;

  final Widget? bottomBar;

  final bool bottomBarFollowsKeyboard;

  final ScrollController? controller;

  /// Ignored when there is a [bottomBar].
  final double bottomPadding;

  /// Replaces the bar title.
  final Widget? barTitle;

  /// A pull to refresh control. It must come first to see the pull, and draws
  /// [RefreshInset.of] below its own top.
  final Widget? refreshSliver;

  final ScrollPhysics? physics;

  final Key? scrollKey;

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  ScrollController? _internalController;
  ScrollController get _controller =>
      widget.controller ?? (_internalController ??= ScrollController());

  double? _bottomBarHeight;

  final _corrections = ScrollCorrections();

  @override
  void dispose() {
    _internalController?.dispose();
    _corrections.dispose();
    super.dispose();
  }

  void _bottomBarHeightChanged(double height) {
    if (!mounted) return;
    final position = _controller.hasClients ? _controller.position : null;
    final isAtEnd =
        position != null &&
        position.pixels > 0 &&
        position.pixels >= position.maxScrollExtent - 1;
    setState(() => _bottomBarHeight = height);
    if (!isAtEnd) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _controller.hasClients) {
        _controller.jumpTo(_controller.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    final top = MediaQuery.paddingOf(context).top;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final canPop = widget.showBack && Navigator.of(context).canPop();
    final leading = widget.leading ?? (canPop ? const PageBackButton() : null);
    final hasBar =
        leading != null ||
        widget.isTitleShown ||
        widget.actions.isNotEmpty ||
        widget.largeTitle != null;

    final bottomBarOffset =
        (widget.bottomBarFollowsKeyboard && keyboard > 0
            ? keyboard
            : context.safeBottom) +
        8;
    final bottomBarInset = widget.bottomBar == null
        ? 0.0
        : math.max(
            0.0,
            bottomBarOffset +
                (_bottomBarHeight ?? context.density.control) -
                keyboard,
          );
    final endSpace = widget.bottomBar == null
        ? math.max(0.0, context.safeBottom - keyboard) + widget.bottomPadding
        : bottomBarInset + context.density.space16;

    final barSpace =
        top +
        (hasBar
            ? PageBar.heightOf(context, isTall: widget.isTall)
            : context.density.space8);
    final slivers = <Widget>[
      if (widget.refreshSliver case final refresh?)
        RefreshInset(top: barSpace, child: refresh),
      SliverToBoxAdapter(child: widget.cover ?? SizedBox(height: barSpace)),
      ...widget.slivers,
      SliverToBoxAdapter(child: SizedBox(height: endSpace)),
    ];

    final scroll = NotificationListener<ScrollMetricsNotification>(
      onNotification: _corrections.onMetrics,
      child: CustomScrollView(
        key: widget.scrollKey,
        controller: _controller,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        physics: widget.physics ?? const AlwaysScrollableScrollPhysics(),
        slivers: slivers,
      ),
    );

    final background = switch (widget.background) {
      PageBackground.plain => ColoredBox(color: colors.appPage),
      PageBackground.gradient => DecoratedBox(
        decoration: BoxDecoration(gradient: pageGradient(context)),
      ),
    };

    final title = widget.isTitleShown
        ? widget.barTitle ?? BarTitle(widget.title, line: widget.titleLine)
        : null;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(child: background),
          // A focused field scrolls into view only inside this viewport.
          Positioned(
            left: 0,
            top: 0,
            right: 0,
            bottom: keyboard,
            child: BottomBarInset(inset: bottomBarInset, child: scroll),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: PageBar(
              leading: leading,
              title: title,
              largeTitle: widget.largeTitle,
              isTall: widget.isTall,
              actions: widget.actions,
              scrollOffset: ScrollOffset(
                _controller,
                corrections: _corrections,
              ),
            ),
          ),
          if (widget.bottomBar case final bottomBar?)
            Positioned(
              left: 16,
              right: 16,
              bottom: bottomBarOffset,
              child: BottomBarFrame(
                bottom: bottomBarOffset,
                onHeightChanged: _bottomBarHeightChanged,
                child: bottomBar,
              ),
            ),
        ],
      ),
    );
  }
}

LinearGradient pageGradient(BuildContext context) {
  final colors = context.anchor;
  final dark = context.isDark;
  return LinearGradient(
    begin: const Alignment(-0.27, -1),
    end: const Alignment(0.27, 1),
    stops: [0, dark ? 0.5 : 0.46],
    colors: [
      Color.lerp(colors.appPage, colors.appSurface, dark ? 0.7 : 0.6)!,
      colors.appPage,
    ],
  );
}

/// How far below its own top a refresh control's indicator starts: the space
/// the bar takes.
class RefreshInset extends InheritedWidget {
  const RefreshInset({super.key, required this.top, required super.child});

  final double top;

  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RefreshInset>()?.top ?? 0;

  @override
  bool updateShouldNotify(RefreshInset oldWidget) => top != oldWidget.top;
}
