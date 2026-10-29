import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Lays [children] out at equal widths, each at least as wide as its content,
/// or stacked with the last on top when they don't fit side by side.
class ButtonRow extends MultiChildRenderObjectWidget {
  const ButtonRow({
    super.key,
    this.spacing = 0,
    this.stackSpacing = 0,
    super.children,
  });

  final double spacing;
  final double stackSpacing;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderButtonRow(
    spacing: spacing,
    stackSpacing: stackSpacing,
    textDirection: Directionality.of(context),
  );

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderButtonRow)
      ..spacing = spacing
      ..stackSpacing = stackSpacing
      ..textDirection = Directionality.of(context);
  }
}

class _ButtonRowParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderButtonRow extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _ButtonRowParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _ButtonRowParentData> {
  _RenderButtonRow({
    required double spacing,
    required double stackSpacing,
    required TextDirection textDirection,
  }) : _spacing = spacing,
       _stackSpacing = stackSpacing,
       _textDirection = textDirection;

  double get spacing => _spacing;
  double _spacing;
  set spacing(double value) {
    if (value == _spacing) return;
    _spacing = value;
    markNeedsLayout();
  }

  double get stackSpacing => _stackSpacing;
  double _stackSpacing;
  set stackSpacing(double value) {
    if (value == _stackSpacing) return;
    _stackSpacing = value;
    markNeedsLayout();
  }

  TextDirection get textDirection => _textDirection;
  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _ButtonRowParentData) {
      child.parentData = _ButtonRowParentData();
    }
  }

  Size _arrange(
    BoxConstraints constraints,
    Size Function(RenderBox child, BoxConstraints constraints) sizeOf, [
    void Function(RenderBox child, Offset offset)? place,
  ]) {
    final buttons = getChildrenAsList();
    final width = constraints.maxWidth;
    if (buttons.isEmpty) return constraints.constrain(Size(width, 0));
    final contentWidths = [
      for (final button in buttons)
        button.getMaxIntrinsicWidth(double.infinity),
    ];
    final room = width - spacing * (buttons.length - 1);
    final isStacked =
        contentWidths.fold(0.0, (sum, each) => sum + each) >
        room + precisionErrorTolerance;

    if (isStacked) {
      var y = 0.0;
      for (final (index, button) in buttons.reversed.indexed) {
        if (index > 0) y += stackSpacing;
        place?.call(button, Offset(0, y));
        y += sizeOf(button, BoxConstraints.tightFor(width: width)).height;
      }
      return constraints.constrain(Size(width, y));
    }

    final widths = List<double?>.filled(buttons.length, null);
    var left = room;
    while (true) {
      final open = [
        for (var i = 0; i < buttons.length; i++)
          if (widths[i] == null) i,
      ];
      if (open.isEmpty) break;
      final share = left / open.length;
      final wider = open.where((i) => contentWidths[i] > share).toList();
      if (wider.isEmpty) {
        for (final i in open) {
          widths[i] = share;
        }
        break;
      }
      for (final i in wider) {
        widths[i] = contentWidths[i];
        left -= contentWidths[i];
      }
    }

    var x = 0.0;
    var height = 0.0;
    for (final (index, button) in buttons.indexed) {
      final buttonWidth = widths[index]!;
      place?.call(
        button,
        Offset(
          textDirection == TextDirection.rtl ? width - x - buttonWidth : x,
          0,
        ),
      );
      final size = sizeOf(button, BoxConstraints.tightFor(width: buttonWidth));
      height = math.max(height, size.height);
      x += buttonWidth + spacing;
    }
    return constraints.constrain(Size(width, height));
  }

  @override
  void performLayout() {
    size = _arrange(
      constraints,
      (child, constraints) {
        child.layout(constraints, parentUsesSize: true);
        return child.size;
      },
      (child, offset) =>
          (child.parentData! as _ButtonRowParentData).offset = offset,
    );
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) => _arrange(
    constraints,
    (child, constraints) => child.getDryLayout(constraints),
  );

  @override
  double computeMinIntrinsicWidth(double height) {
    var width = 0.0;
    for (var child = firstChild; child != null; child = childAfter(child)) {
      width = math.max(width, child.getMinIntrinsicWidth(double.infinity));
    }
    return width;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    var width = 0.0;
    for (var child = firstChild; child != null; child = childAfter(child)) {
      if (child != firstChild) width += spacing;
      width += child.getMaxIntrinsicWidth(double.infinity);
    }
    return width;
  }

  @override
  double computeMinIntrinsicHeight(double width) =>
      computeDryLayout(BoxConstraints(maxWidth: width)).height;

  @override
  double computeMaxIntrinsicHeight(double width) =>
      computeMinIntrinsicHeight(width);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);
}
