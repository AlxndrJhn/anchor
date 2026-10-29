import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

class BottomBarFrame extends SingleChildRenderObjectWidget {
  const BottomBarFrame({
    super.key,
    required this.bottom,
    this.isShown = true,
    this.onHeightChanged,
    required super.child,
  });

  /// How far the bar sits above the screen's bottom.
  final double bottom;

  final bool isShown;

  final ValueChanged<double>? onHeightChanged;

  static final Listenable changes = _changes;
  static final _Changes _changes = _Changes();

  static final Map<Route<Object?>, Map<_RenderBottomBarFrame, double>>
  _barHeights = {};

  /// While [page] is closing, the inset on the page under it.
  static double insetOn(Route<Object?>? page, NavigatorState? navigator) {
    if (page == null) return 0;
    var showing = page;
    if (!page.isActive) {
      final under = _barHeights.keys
          .where((route) => route.isCurrent && route.navigator == navigator)
          .firstOrNull;
      if (under == null) return 0;
      showing = under;
    }
    final parts = _barHeights[showing]?.values;
    return parts == null || parts.isEmpty ? 0 : parts.reduce(math.max);
  }

  static void _set(
    _RenderBottomBarFrame part,
    Route<Object?> route,
    double? inset,
  ) {
    final parts = _barHeights.putIfAbsent(route, () => {});
    if (inset == null) {
      parts.remove(part);
      if (parts.isEmpty) _barHeights.remove(route);
    } else {
      parts[part] = inset;
    }
    _changes.notify();
  }

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderBottomBarFrame(
        route: ModalRoute.of(context),
        bottom: bottom,
        isShown: isShown,
        onHeightChanged: onHeightChanged,
      );

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderBottomBarFrame)
      ..route = ModalRoute.of(context)
      ..bottom = bottom
      ..isShown = isShown
      ..onHeightChanged = onHeightChanged;
  }
}

class _Changes extends ChangeNotifier {
  void notify() => notifyListeners();
}

class _RenderBottomBarFrame extends RenderProxyBox {
  _RenderBottomBarFrame({
    required Route<Object?>? route,
    required double bottom,
    required bool isShown,
    required this.onHeightChanged,
  }) : _route = route,
       _bottom = bottom,
       _isShown = isShown;

  ValueChanged<double>? onHeightChanged;

  Route<Object?>? _route;
  set route(Route<Object?>? value) {
    if (value == _route) return;
    _leave();
    _route = value;
    markNeedsLayout();
  }

  double _bottom;
  set bottom(double value) {
    if (value == _bottom) return;
    _bottom = value;
    markNeedsLayout();
  }

  bool _isShown;
  set isShown(bool value) {
    if (value == _isShown) return;
    _isShown = value;
    markNeedsLayout();
  }

  double? _inset;
  double? _height;

  @override
  void performLayout() {
    super.performLayout();
    final height = size.height;
    final inset = _isShown ? _bottom + height : null;
    final route = _route;
    if (inset == _inset && height == _height) return;
    final heightChanged = height != _height;
    _inset = inset;
    _height = height;
    // Listeners can't rebuild during layout.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!attached || _route != route) return;
      if (route != null) BottomBarFrame._set(this, route, inset);
      if (heightChanged) onHeightChanged?.call(height);
    });
  }

  void _leave() {
    final route = _route;
    _inset = null;
    if (route == null) return;
    SchedulerBinding.instance.addPostFrameCallback(
      (_) => BottomBarFrame._set(this, route, null),
    );
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    markNeedsLayout();
  }

  @override
  void detach() {
    _leave();
    super.detach();
  }
}

class BottomBarInset extends InheritedWidget {
  const BottomBarInset({super.key, required this.inset, required super.child});

  final double inset;

  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BottomBarInset>()?.inset ?? 0;

  @override
  bool updateShouldNotify(BottomBarInset oldWidget) => oldWidget.inset != inset;
}
