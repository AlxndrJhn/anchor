import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
// Quill keeps a line's spacing on its render object and exports no hook for
// one line's spacing.
// ignore: implementation_imports
import 'package:flutter_quill/src/editor/widgets/text/text_line.dart'
    show RenderEditableTextLine;

import '../../../../core/theme/tokens/anchor_tokens.dart';

class ListLineLeading extends MultiChildRenderObjectWidget {
  ListLineLeading({
    super.key,
    required this.top,
    required this.bottom,
    required Widget marker,
    this.markerRect,
    Widget? row,
    this.rowHeight = 0,
    this.rowAbove = 0,
    this.guides = 0,
    this.guideColor = const Color(0x00000000),
    this.guideReach = 0,
  }) : super(children: [marker, ?row]);

  final double top;

  final double bottom;

  /// A line under each level above this one's marker.
  final int guides;

  final Color guideColor;

  /// How far the guides reach past the text, to meet the next line's.
  final double guideReach;

  /// From the top left of the line's first row of text.
  final Rect? markerRect;

  final double rowHeight;

  final double rowAbove;

  @override
  RenderListLineLeading createRenderObject(BuildContext context) =>
      RenderListLineLeading(
        top: top,
        bottom: bottom,
        markerRect: markerRect,
        rowHeight: rowHeight,
        rowAbove: rowAbove,
        guides: guides,
        guideColor: guideColor,
        guideReach: guideReach,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderListLineLeading renderObject,
  ) {
    renderObject
      ..top = top
      ..bottom = bottom
      ..markerRect = markerRect
      ..rowHeight = rowHeight
      ..rowAbove = rowAbove
      ..guides = guides
      ..guideColor = guideColor
      ..guideReach = guideReach
      // Quill has just put back its own spacing for the line.
      ..applySpacing();
  }
}

/// Under the middle of a level's 22 wide marker column.
const double _guideLeft = 11; // off-scale: list guide

class _LeadingParentData extends ContainerBoxParentData<RenderBox> {}

class RenderListLineLeading extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _LeadingParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _LeadingParentData> {
  RenderListLineLeading({
    required double top,
    required double bottom,
    Rect? markerRect,
    required double rowHeight,
    required double rowAbove,
    int guides = 0,
    Color guideColor = const Color(0x00000000),
    double guideReach = 0,
  }) : _top = top,
       _bottom = bottom,
       _markerRect = markerRect,
       _rowHeight = rowHeight,
       _rowAbove = rowAbove,
       _guides = guides,
       _guideColor = guideColor,
       _guideReach = guideReach;

  double _top;
  set top(double value) {
    if (_top == value) return;
    _top = value;
    markNeedsLayout();
  }

  double _bottom;
  set bottom(double value) => _bottom = value;

  Rect? _markerRect;
  set markerRect(Rect? value) {
    if (_markerRect == value) return;
    _markerRect = value;
    markNeedsLayout();
  }

  double _rowHeight;
  set rowHeight(double value) {
    if (_rowHeight == value) return;
    _rowHeight = value;
    markNeedsLayout();
  }

  double _rowAbove;
  set rowAbove(double value) {
    if (_rowAbove == value) return;
    _rowAbove = value;
    markNeedsLayout();
  }

  int _guides;
  set guides(int value) {
    if (_guides == value) return;
    _guides = value;
    markNeedsPaint();
  }

  Color _guideColor;
  set guideColor(Color value) {
    if (_guideColor == value) return;
    _guideColor = value;
    markNeedsPaint();
  }

  double _guideReach;
  set guideReach(double value) {
    if (_guideReach == value) return;
    _guideReach = value;
    markNeedsPaint();
  }

  RenderBox? get _marker => firstChild;

  RenderBox? get _row => _marker == null ? null : childAfter(_marker!);

  void applySpacing() {
    final line = parent;
    if (line is! RenderEditableTextLine) return;
    final padding = line.padding;
    line.setPadding(switch (padding) {
      EdgeInsetsDirectional() => padding.copyWith(top: _top, bottom: _bottom),
      EdgeInsets() => padding.copyWith(top: _top, bottom: _bottom),
      _ => padding,
    });
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    applySpacing();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _LeadingParentData) {
      child.parentData = _LeadingParentData();
    }
  }

  @override
  void performLayout() {
    size = constraints.biggest;
    final marker = _marker;
    if (marker != null) {
      final rect = _markerRect;
      marker.layout(
        rect == null
            ? BoxConstraints.tight(size)
            : BoxConstraints.tight(rect.size),
      );
      (marker.parentData! as _LeadingParentData).offset =
          rect?.topLeft ?? Offset.zero;
    }
    final row = _row;
    if (row != null) {
      final line = parent;
      row.layout(
        BoxConstraints(
          maxWidth: line is RenderBox ? line.constraints.maxWidth : size.width,
          minHeight: _rowHeight,
          maxHeight: _rowHeight,
        ),
      );
      (row.parentData! as _LeadingParentData).offset = Offset(0, -_rowAbove);
    }
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  double computeMinIntrinsicWidth(double height) => 0;

  @override
  double computeMaxIntrinsicWidth(double height) => 0;

  @override
  double computeMinIntrinsicHeight(double width) => 0;

  @override
  double computeMaxIntrinsicHeight(double width) => 0;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_guides > 0 && _guideColor.a > 0) {
      final paint = Paint()..color = _guideColor;
      for (var level = 0; level < _guides; level++) {
        context.canvas.drawRect(
          Rect.fromLTWH(
            offset.dx + _guideLeft + level * AnchorTokens.sizeListIndent,
            offset.dy - _guideReach,
            1,
            size.height + 2 * _guideReach,
          ),
          paint,
        );
      }
    }
    defaultPaint(context, offset);
  }

  /// The marker and the row reach past the leading's own box.
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!hitTestChildren(result, position: position)) return false;
    result.add(BoxHitTestEntry(this, position));
    return true;
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
