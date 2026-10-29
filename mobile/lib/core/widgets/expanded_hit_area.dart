import 'dart:math' as math;

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
