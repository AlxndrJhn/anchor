import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Lays [children] out in runs like a [Wrap], each centered on its run, with
/// [trailing] at the end of the last run, or of its own run when it doesn't
/// fit there.
class TrailingWrap extends MultiChildRenderObjectWidget {
  TrailingWrap({
    super.key,
    this.spacing = 0,
    this.runSpacing = 0,
    List<Widget> children = const [],
    Widget? trailing,
  }) : hasTrailing = trailing != null,
       super(children: [...children, ?trailing]);

  final double spacing;
  final double runSpacing;
  final bool hasTrailing;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderTrailingWrap(
    spacing: spacing,
    runSpacing: runSpacing,
    hasTrailing: hasTrailing,
    textDirection: Directionality.of(context),
  );

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderTrailingWrap)
      ..spacing = spacing
      ..runSpacing = runSpacing
      ..hasTrailing = hasTrailing
      ..textDirection = Directionality.of(context);
  }
}

class _TrailingWrapParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderTrailingWrap extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _TrailingWrapParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _TrailingWrapParentData> {
  _RenderTrailingWrap({
    required double spacing,
    required double runSpacing,
    required bool hasTrailing,
    required TextDirection textDirection,
  }) : _spacing = spacing,
       _runSpacing = runSpacing,
       _hasTrailing = hasTrailing,
       _textDirection = textDirection;

  double get spacing => _spacing;
  double _spacing;
  set spacing(double value) {
    if (value == _spacing) return;
    _spacing = value;
    markNeedsLayout();
  }

  double get runSpacing => _runSpacing;
  double _runSpacing;
  set runSpacing(double value) {
    if (value == _runSpacing) return;
    _runSpacing = value;
    markNeedsLayout();
  }

  bool get hasTrailing => _hasTrailing;
  bool _hasTrailing;
  set hasTrailing(bool value) {
    if (value == _hasTrailing) return;
    _hasTrailing = value;
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
    if (child.parentData is! _TrailingWrapParentData) {
      child.parentData = _TrailingWrapParentData();
    }
  }

  Size _arrange(
    BoxConstraints constraints,
    Size Function(RenderBox child, BoxConstraints constraints) sizeOf, [
    void Function(RenderBox child, Offset offset)? place,
  ]) {
    final maxWidth = constraints.maxWidth;
    final childConstraints = BoxConstraints(maxWidth: maxWidth);
    final runs = <List<(RenderBox, Size)>>[];
    var runWidth = 0.0;
    var width = 0.0;
    for (var child = firstChild; child != null; child = childAfter(child)) {
      final size = sizeOf(child, childConstraints);
      if (runs.isEmpty ||
          runWidth + spacing + size.width >
              maxWidth + precisionErrorTolerance) {
        runs.add([(child, size)]);
        runWidth = size.width;
      } else {
        runs.last.add((child, size));
        runWidth += spacing + size.width;
      }
      width = math.max(width, runWidth);
    }
    if (hasTrailing && maxWidth.isFinite) width = maxWidth;

    var y = 0.0;
    for (final (index, run) in runs.indexed) {
      if (index > 0) y += runSpacing;
      final height = run.fold(
        0.0,
        (most, entry) => math.max(most, entry.$2.height),
      );
      var x = 0.0;
      for (final (child, size) in run) {
        final isTrailing = hasTrailing && childAfter(child) == null;
        final left = isTrailing ? width - size.width : x;
        place?.call(
          child,
          Offset(
            textDirection == TextDirection.rtl
                ? width - left - size.width
                : left,
            y + (height - size.height) / 2,
          ),
        );
        x += size.width + spacing;
      }
      y += height;
    }
    return constraints.constrain(Size(width, y));
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
          (child.parentData! as _TrailingWrapParentData).offset = offset,
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
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      defaultComputeDistanceToHighestActualBaseline(baseline);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);
}
