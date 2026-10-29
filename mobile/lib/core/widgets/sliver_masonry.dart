import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// A lazy grid that puts each child in the shortest column. Heights it has
/// measured, kept by [itemKeys], place the children above the ones shown.
class SliverMasonry extends SliverMultiBoxAdaptorWidget {
  SliverMasonry({
    super.key,
    required this.itemKeys,
    required NullableIndexedWidgetBuilder itemBuilder,
    this.columnCount = 2,
    this.mainAxisSpacing = 0,
    this.crossAxisSpacing = 0,
  }) : super(
         delegate: SliverChildBuilderDelegate(
           itemBuilder,
           childCount: itemKeys.length,
         ),
       );

  /// One per child, the same child keeping the same key across rebuilds.
  final List<Object> itemKeys;

  final int columnCount;
  final double mainAxisSpacing;
  final double crossAxisSpacing;

  @override
  RenderSliverMasonry createRenderObject(BuildContext context) =>
      RenderSliverMasonry(
        childManager: context as SliverMultiBoxAdaptorElement,
        itemKeys: itemKeys,
        columnCount: columnCount,
        mainAxisSpacing: mainAxisSpacing,
        crossAxisSpacing: crossAxisSpacing,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderSliverMasonry renderObject,
  ) {
    renderObject
      ..itemKeys = itemKeys
      ..columnCount = columnCount
      ..mainAxisSpacing = mainAxisSpacing
      ..crossAxisSpacing = crossAxisSpacing;
  }
}

class _MasonryParentData extends SliverMultiBoxAdaptorParentData {
  int column = 0;
}

class RenderSliverMasonry extends RenderSliverMultiBoxAdaptor {
  RenderSliverMasonry({
    required super.childManager,
    required List<Object> itemKeys,
    required int columnCount,
    required double mainAxisSpacing,
    required double crossAxisSpacing,
  }) : assert(columnCount > 0),
       _itemKeys = itemKeys,
       _columnCount = columnCount,
       _mainAxisSpacing = mainAxisSpacing,
       _crossAxisSpacing = crossAxisSpacing;

  List<Object> _itemKeys;
  set itemKeys(List<Object> value) {
    if (listEquals(value, _itemKeys)) return;
    _itemKeys = value;
    final kept = value.toSet();
    _extents.removeWhere((key, _) => !kept.contains(key));
    _isPlaced = false;
    markNeedsLayout();
  }

  int _columnCount;
  int get columnCount => _columnCount;
  set columnCount(int value) {
    assert(value > 0);
    if (value == _columnCount) return;
    _columnCount = value;
    markNeedsLayout();
  }

  double _mainAxisSpacing;
  set mainAxisSpacing(double value) {
    if (value == _mainAxisSpacing) return;
    _mainAxisSpacing = value;
    _isPlaced = false;
    markNeedsLayout();
  }

  double _crossAxisSpacing;
  set crossAxisSpacing(double value) {
    if (value == _crossAxisSpacing) return;
    _crossAxisSpacing = value;
    markNeedsLayout();
  }

  final Map<Object, double> _extents = {};
  double? _childWidth;
  double _stride = 0;

  bool _isPlaced = false;
  double _estimate = 0;
  List<double> _offsets = const [];
  List<int> _columns = const [];
  double _endOffset = 0;

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! _MasonryParentData) {
      child.parentData = _MasonryParentData();
    }
  }

  @override
  double childCrossAxisPosition(RenderBox child) {
    final column = (child.parentData! as _MasonryParentData).column;
    final reversed = axisDirectionIsReversed(constraints.crossAxisDirection);
    return (reversed ? _columnCount - 1 - column : column) * _stride;
  }

  double _extentAt(int index) => _extents[_itemKeys[index]] ?? _estimate;

  void _place() {
    if (_isPlaced) return;
    final count = _itemKeys.length;
    _estimate = _extents.isEmpty
        ? _childWidth ?? 0
        : _extents.values.reduce((a, b) => a + b) / _extents.length;
    final ends = List<double>.filled(_columnCount, 0);
    if (_offsets.length != count) {
      _offsets = List<double>.filled(count, 0);
      _columns = List<int>.filled(count, 0);
    }
    for (var i = 0; i < count; i++) {
      final lowest = ends.reduce(math.min);
      var column = 0;
      while (ends[column] > lowest + _mainAxisSpacing) {
        column++;
      }
      _offsets[i] = ends[column];
      _columns[i] = column;
      ends[column] += _extentAt(i) + _mainAxisSpacing;
    }
    _endOffset = count == 0 ? 0 : ends.reduce(math.max) - _mainAxisSpacing;
    _isPlaced = true;
  }

  /// True when [child]'s extent differs from the one placed.
  bool _measure(RenderBox child) {
    final key = _itemKeys[indexOf(child)];
    final extent = paintExtentOf(child);
    if (_extents[key] == extent) return false;
    _extents[key] = extent;
    _isPlaced = false;
    return true;
  }

  bool _keepChildren(int from, int to, BoxConstraints childConstraints) {
    if (to < from) {
      if (firstChild != null) collectGarbage(childCount, 0);
      return false;
    }
    if (firstChild != null) {
      if (indexOf(lastChild!) < from || indexOf(firstChild!) > to) {
        collectGarbage(childCount, 0);
      } else {
        var leading = 0;
        for (var c = firstChild; c != null && indexOf(c) < from;) {
          leading++;
          c = childAfter(c);
        }
        var trailing = 0;
        for (var c = lastChild; c != null && indexOf(c) > to;) {
          trailing++;
          c = childBefore(c);
        }
        if (leading + trailing > 0) collectGarbage(leading, trailing);
      }
    }
    var changed = false;
    if (firstChild == null) {
      if (!addInitialChild(index: from, layoutOffset: _offsets[from])) {
        return false;
      }
      firstChild!.layout(childConstraints, parentUsesSize: true);
      changed |= _measure(firstChild!);
    }
    while (indexOf(firstChild!) > from) {
      final child = insertAndLayoutLeadingChild(
        childConstraints,
        parentUsesSize: true,
      );
      if (child == null) break;
      changed |= _measure(child);
    }
    while (indexOf(lastChild!) < to) {
      final child = insertAndLayoutChild(
        childConstraints,
        after: lastChild,
        parentUsesSize: true,
      );
      if (child == null) break;
      changed |= _measure(child);
    }
    return changed;
  }

  @override
  void performLayout() {
    final constraints = this.constraints;
    childManager
      ..didStartLayout()
      ..setDidUnderflow(false);

    _stride = (constraints.crossAxisExtent + _crossAxisSpacing) / _columnCount;
    final childWidth = math.max(0.0, _stride - _crossAxisSpacing);
    if (childWidth != _childWidth) {
      _childWidth = childWidth;
      _extents.clear();
      _isPlaced = false;
    }
    final childConstraints = constraints.asBoxConstraints(
      crossAxisExtent: childWidth,
    );

    final count = _itemKeys.length;
    assert(count == childManager.childCount);
    if (count == 0) {
      if (firstChild != null) collectGarbage(childCount, 0);
      _isPlaced = false;
      _place();
      geometry = SliverGeometry.zero;
      childManager.didFinishLayout();
      return;
    }

    for (var c = firstChild; c != null; c = childAfter(c)) {
      c.layout(childConstraints, parentUsesSize: true);
      _measure(c);
    }

    final start = math.max(
      0.0,
      constraints.scrollOffset + constraints.cacheOrigin,
    );
    final end = start + constraints.remainingCacheExtent;
    var first = 0;
    var last = -1;
    while (true) {
      _place();
      first = 0;
      while (first < count && _offsets[first] + _extentAt(first) <= start) {
        first++;
      }
      last = count - 1;
      while (last >= 0 && _offsets[last] >= end) {
        last--;
      }
      var unmeasured = 0;
      while (unmeasured < count &&
          _extents.containsKey(_itemKeys[unmeasured])) {
        unmeasured++;
      }
      final from = unmeasured <= last ? math.min(first, unmeasured) : first;
      if (!_keepChildren(from, last, childConstraints)) break;
    }
    _keepChildren(first, last, childConstraints);

    for (var c = firstChild; c != null; c = childAfter(c)) {
      final index = indexOf(c);
      (c.parentData! as _MasonryParentData)
        ..layoutOffset = _offsets[index]
        ..column = _columns[index];
    }

    final paintExtent = calculatePaintOffset(
      constraints,
      from: 0,
      to: _endOffset,
    );
    geometry = SliverGeometry(
      scrollExtent: _endOffset,
      paintExtent: paintExtent,
      cacheExtent: calculateCacheOffset(constraints, from: 0, to: _endOffset),
      maxPaintExtent: _endOffset,
      hasVisualOverflow:
          _endOffset >
              constraints.scrollOffset + constraints.remainingPaintExtent ||
          constraints.scrollOffset > 0,
    );
    childManager.didFinishLayout();
  }
}
