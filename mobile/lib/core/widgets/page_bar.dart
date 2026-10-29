import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/l10n.dart';
import '../motion/springs.dart';
import '../theme/context_extensions.dart';
import '../theme/tokens/anchor_tokens.dart';
import 'app_buttons.dart';
import 'frosted_glass.dart';
import 'page_settled.dart';

/// Hears offset corrections a scroll view makes without notifying its
/// controller. Feed it the view's [ScrollMetricsNotification]s.
class ScrollCorrections extends ChangeNotifier {
  bool onMetrics(ScrollMetricsNotification notification) {
    if (notification.depth == 0) notifyListeners();
    return false;
  }
}

@immutable
class ScrollOffset implements ValueListenable<double> {
  const ScrollOffset(this.controller, {this.corrections});

  final ScrollController controller;
  final ScrollCorrections? corrections;

  @override
  double get value => controller.hasClients ? controller.offset : 0;

  @override
  void addListener(VoidCallback listener) {
    controller.addListener(listener);
    corrections?.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    controller.removeListener(listener);
    corrections?.removeListener(listener);
  }

  @override
  bool operator ==(Object other) =>
      other is ScrollOffset &&
      other.controller == controller &&
      other.corrections == corrections;

  @override
  int get hashCode => Object.hash(controller, corrections);
}

class PageBar extends StatefulWidget {
  const PageBar({
    super.key,
    this.leading,
    this.title,
    this.largeTitle,
    this.actions = const [],
    this.color,
    this.scrollOffset,
    this.isTitleCentered,
    this.isHidden = false,
    this.isTall = false,
    this.systemBars,
  });

  /// Excludes the status bar.
  static double heightOf(BuildContext context, {bool isTall = false}) =>
      isTall ? context.density.largeBar : context.density.bar;

  static const double inset =
      16 - (AnchorTokens.sizeControlMedium - AnchorTokens.sizeIconLarge) / 2;

  static const double titleTransitionDistance =
      56; // off-scale: the large title's travel

  static const double _titleSide = 68; // off-scale: one button's room

  final Widget? leading;
  final Widget? title;

  final Widget? largeTitle;

  final List<Widget> actions;

  final Color? color;

  final ValueListenable<double>? scrollOffset;

  /// Centered on iPhone and at the start on Android unless set.
  final bool? isTitleCentered;

  /// Fades the bar away and lets touches through.
  final bool isHidden;

  /// Room for a large title; shrinks to the regular bar as the title hands
  /// over.
  final bool isTall;

  final SystemUiOverlayStyle? systemBars;

  @override
  State<PageBar> createState() => _PageBarState();
}

class _PageBarState extends State<PageBar> {
  final ValueNotifier<bool> _isUnder = ValueNotifier(false);

  final ValueNotifier<double> _progress = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    widget.scrollOffset?.addListener(_scrolled);
    _scrolled();
  }

  @override
  void didUpdateWidget(PageBar old) {
    super.didUpdateWidget(old);
    if (old.scrollOffset != widget.scrollOffset) {
      old.scrollOffset?.removeListener(_scrolled);
      widget.scrollOffset?.addListener(_scrolled);
      _scrolled();
    }
  }

  @override
  void dispose() {
    widget.scrollOffset?.removeListener(_scrolled);
    _isUnder.dispose();
    _progress.dispose();
    super.dispose();
  }

  void _scrolled() {
    final offset = widget.scrollOffset?.value ?? 0;
    _isUnder.value = offset > 2;
    _progress.value = (offset / PageBar.titleTransitionDistance).clamp(
      -_maxPull,
      1.0,
    );
  }

  static const double _maxPull =
      0.06 * _pullPerScale / PageBar.titleTransitionDistance;
  static const double _pullPerScale = 1400; // off-scale: pull per unit scale

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final hasLarge = widget.largeTitle != null;
    final isEmpty =
        widget.leading == null &&
        widget.title == null &&
        !hasLarge &&
        widget.actions.isEmpty;
    final restHeight = isEmpty
        ? 0.0
        : PageBar.heightOf(context, isTall: widget.isTall);
    final scrolledHeight = isEmpty ? 0.0 : PageBar.heightOf(context);
    final centered = widget.isTitleCentered ?? context.isCupertino;
    final double titleLeft = centered
        ? PageBar._titleSide
        : (widget.leading != null
              ? PageBar.inset + AnchorTokens.sizeControlMedium + 12
              : 16);

    final children = [
      if (widget.leading case final leading?)
        LayoutId(id: _Slot.leading, child: leading),
      if (widget.title case final title?)
        LayoutId(
          id: _Slot.title,
          child: Align(
            alignment: centered
                ? Alignment.center
                : AlignmentDirectional.centerStart,
            child: hasLarge
                ? _TitleTransition(
                    progress: _progress,
                    isLarge: false,
                    child: title,
                  )
                : title,
          ),
        ),
      if (widget.largeTitle case final large?)
        LayoutId(
          id: _Slot.large,
          child: _TitleTransition(
            progress: _progress,
            isLarge: true,
            origin: Offset(0, top + restHeight / 2),
            child: large,
          ),
        ),
      if (widget.actions.isNotEmpty)
        LayoutId(
          id: _Slot.actions,
          child: Row(mainAxisSize: MainAxisSize.min, children: widget.actions),
        ),
    ];
    final background = Positioned.fill(
      child: _FrostedBackground(
        color: widget.color ?? context.anchor.appPage,
        isUnder: _isUnder,
        hasHairline: !isEmpty,
      ),
    );

    Widget barOf(double height) => SizedBox(
      height: top + height,
      child: Stack(
        children: [
          background,
          Positioned.fill(
            child: CustomMultiChildLayout(
              delegate: _BarLayout(
                top: top,
                height: height,
                titleLeft: titleLeft,
                titleRight: PageBar._titleSide,
              ),
              children: children,
            ),
          ),
        ],
      ),
    );

    final bar = restHeight == scrolledHeight
        ? barOf(restHeight)
        : ValueListenableBuilder<double>(
            valueListenable: _progress,
            builder: (context, progress, _) => barOf(
              restHeight +
                  (scrolledHeight - restHeight) * progress.clamp(0.0, 1.0),
            ),
          );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: widget.systemBars ?? context.systemBars,
      child: IgnorePointer(
        ignoring: widget.isHidden,
        child: AnimatedOpacity(
          opacity: widget.isHidden ? 0 : 1,
          duration: context.motion(AnchorTokens.motionDurationFade),
          child: bar,
        ),
      ),
    );
  }
}

enum _Slot { leading, title, large, actions }

class _BarLayout extends MultiChildLayoutDelegate {
  _BarLayout({
    required this.top,
    required this.height,
    required this.titleLeft,
    required this.titleRight,
  });

  final double top;
  final double height;
  final double titleLeft;
  final double titleRight;

  @override
  void performLayout(Size size) {
    final row = BoxConstraints.loose(Size(size.width, height));
    double centered(Size child) => top + (height - child.height) / 2;
    if (hasChild(_Slot.leading)) {
      final leading = layoutChild(_Slot.leading, row);
      positionChild(_Slot.leading, Offset(PageBar.inset, centered(leading)));
    }
    var actionsWidth = 0.0;
    if (hasChild(_Slot.actions)) {
      final actions = layoutChild(_Slot.actions, row);
      actionsWidth = actions.width;
      positionChild(
        _Slot.actions,
        Offset(size.width - PageBar.inset - actions.width, centered(actions)),
      );
    }
    if (hasChild(_Slot.title)) {
      layoutChild(
        _Slot.title,
        BoxConstraints.tight(
          Size(math.max(0, size.width - titleLeft - titleRight), height),
        ),
      );
      positionChild(_Slot.title, Offset(titleLeft, top));
    }
    if (hasChild(_Slot.large)) {
      layoutChild(
        _Slot.large,
        BoxConstraints(
          maxWidth: math.max(0, size.width - 16 - PageBar.inset - actionsWidth),
          minHeight: size.height,
          maxHeight: size.height,
        ),
      );
      positionChild(_Slot.large, const Offset(16, 0));
    }
  }

  @override
  bool shouldRelayout(_BarLayout old) =>
      old.top != top ||
      old.height != height ||
      old.titleLeft != titleLeft ||
      old.titleRight != titleRight;
}

class _TitleTransition extends StatelessWidget {
  const _TitleTransition({
    required this.progress,
    required this.isLarge,
    required this.child,
    this.origin = Offset.zero,
  });

  final ValueListenable<double> progress;
  final bool isLarge;
  final Offset origin;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: progress,
      child: RepaintBoundary(child: child),
      builder: (context, progress, child) {
        final collapseProgress = math.max(0.0, progress);
        final isAway = isLarge
            ? collapseProgress >= 0.5
            : collapseProgress < 0.5;
        Widget shown = child!;
        if (isLarge) {
          final pull =
              math.max(0.0, -progress) * PageBar.titleTransitionDistance;
          final scale =
              (1 - 0.1 * collapseProgress) *
              (1 + pull / _PageBarState._pullPerScale);
          shown = Transform(
            origin: origin,
            transform: Matrix4.translationValues(0, -8 * collapseProgress, 0)
              ..scaleByDouble(scale, scale, 1, 1),
            child: shown,
          );
        }
        return Opacity(
          opacity:
              (isLarge ? 1 - 1.8 * collapseProgress : 2 * collapseProgress - 1)
                  .clamp(0.0, 1.0),
          child: IgnorePointer(
            ignoring: isAway,
            child: ExcludeSemantics(excluding: isAway, child: shown),
          ),
        );
      },
    );
  }
}

class _FrostedBackground extends StatelessWidget {
  const _FrostedBackground({
    required this.color,
    required this.isUnder,
    required this.hasHairline,
  });

  final Color color;
  final ValueListenable<bool> isUnder;
  final bool hasHairline;

  static final _filter = frostedGlassFilter(20);

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    return IgnorePointer(
      child: ValueListenableBuilder<bool>(
        valueListenable: isUnder,
        builder: (context, isUnder, _) => PageSettledBuilder(
          builder: (context, settled) {
            final tint = AnimatedOpacity(
              opacity: isUnder ? 1 : 0,
              duration: context.motion(AnchorTokens.motionDurationFade),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: settled ? color.withValues(alpha: 0.78) : color,
                  border: hasHairline
                      ? Border(
                          bottom: BorderSide(
                            color: colors.appText.withValues(alpha: 0.18),
                            width: 0.5,
                          ),
                        )
                      : null,
                ),
              ),
            );
            return ClipRect(
              child: BackdropFilter.grouped(
                enabled: settled && isUnder,
                filter: _filter,
                child: tint,
              ),
            );
          },
        ),
      ),
    );
  }
}

class PageBackButton extends StatelessWidget {
  const PageBackButton({super.key, this.label, this.onPressed});

  final String? label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return BarButton(
      icon: backIcon(context),
      label: label ?? context.l10n.commonBack,
      onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
    );
  }
}
