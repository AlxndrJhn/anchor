import 'dart:math' as math;

import 'package:flutter/material.dart' show Theme, kMinInteractiveDimension;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Taps within [padding] around the child land on the nearest point inside it.
/// The layout keeps the child's size.
class ExpandedHitArea extends SingleChildRenderObjectWidget {
  const ExpandedHitArea({
    super.key,
    required this.padding,
    required super.child,
  });

  final EdgeInsets padding;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderExpandedHitArea(padding);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderExpandedHitArea).padding = padding;
  }
}

class _RenderExpandedHitArea extends RenderProxyBox {
  _RenderExpandedHitArea(this.padding);

  EdgeInsets padding;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!padding.inflateRect(Offset.zero & size).contains(position)) {
      return false;
    }
    const inset = 0.001;
    final inside = Offset(
      position.dx.clamp(0, math.max(0, size.width - inset)),
      position.dy.clamp(0, math.max(0, size.height - inset)),
    );
    return super.hitTest(result, position: inside);
  }
}

/// Touches and screen readers find [child] within the platform's smallest
/// target, 48 on Android and 44 on iPhone, even where it's drawn smaller.
/// The layout keeps the child's size: the room around it overlaps its
/// neighbours, and taps there land on the nearest point inside it. Its
/// semantics merge into one node that covers the whole target.
class MinTapTarget extends SingleChildRenderObjectWidget {
  const MinTapTarget({super.key, this.size, required super.child});

  /// Null for the platform's.
  final double? size;

  static double sizeOf(BuildContext context) =>
      switch (Theme.of(context).platform) {
        TargetPlatform.iOS || TargetPlatform.macOS => _apple,
        _ => kMinInteractiveDimension,
      };

  static const double _apple = 44; // off-scale: Apple's smallest target

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMinTapTarget(size ?? sizeOf(context));

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderMinTapTarget).minSize = size ?? sizeOf(context);
  }
}

class _RenderMinTapTarget extends RenderProxyBox {
  _RenderMinTapTarget(this._minSize);

  double _minSize;

  set minSize(double value) {
    if (value == _minSize) return;
    _minSize = value;
    markNeedsSemanticsUpdate();
  }

  Size? _laidOut;

  EdgeInsets get _room => EdgeInsets.symmetric(
    horizontal: math.max(0, (_minSize - size.width) / 2),
    vertical: math.max(0, (_minSize - size.height) / 2),
  );

  @override
  void performLayout() {
    super.performLayout();
    if (size != _laidOut) {
      _laidOut = size;
      markNeedsSemanticsUpdate();
    }
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!_room.inflateRect(Offset.zero & size).contains(position)) {
      return false;
    }
    const inset = 0.001;
    final inside = Offset(
      position.dx.clamp(0, math.max(0, size.width - inset)),
      position.dy.clamp(0, math.max(0, size.height - inset)),
    );
    return super.hitTest(result, position: inside);
  }

  @override
  Rect get semanticBounds => _room.inflateRect(Offset.zero & size);

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config
      ..isSemanticBoundary = true
      ..isMergingSemanticsOfDescendants = true;
  }
}
