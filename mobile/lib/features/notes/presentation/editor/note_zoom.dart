import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../../../core/motion/haptics.dart';

const double minNoteZoom = 1;
const double maxNoteZoom = 2.5;

/// Within this of 1, a pinch lets go at 1, the body's own size.
const double _snapToOne = 0.06;

double clampNoteZoom(double zoom) {
  if (!zoom.isFinite) return minNoteZoom;
  final clamped = zoom.clamp(minNoteZoom, maxNoteZoom).toDouble();
  return clamped - minNoteZoom < _snapToOne ? minNoteZoom : clamped;
}

/// Lays [child] out [zoom] times narrower and draws it [zoom] times larger,
/// so text, checkboxes and indents grow together and still wrap to the width.
class ZoomedBox extends SingleChildRenderObjectWidget {
  const ZoomedBox({super.key, required this.zoom, super.child});

  final double zoom;

  @override
  RenderZoomedBox createRenderObject(BuildContext context) =>
      RenderZoomedBox(zoom);

  @override
  void updateRenderObject(BuildContext context, RenderZoomedBox renderObject) {
    renderObject.zoom = zoom;
  }
}

class RenderZoomedBox extends RenderProxyBox {
  RenderZoomedBox(this._zoom);

  double _zoom;
  double get zoom => _zoom;
  set zoom(double value) {
    if (value == _zoom) return;
    _zoom = value;
    markNeedsLayout();
  }

  Matrix4 get _transform => Matrix4.diagonal3Values(_zoom, _zoom, 1);

  BoxConstraints _inner(BoxConstraints constraints) => BoxConstraints(
    minWidth: constraints.minWidth / _zoom,
    maxWidth: constraints.maxWidth / _zoom,
    minHeight: constraints.minHeight / _zoom,
    maxHeight: constraints.maxHeight / _zoom,
  );

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(_inner(constraints), parentUsesSize: true);
    size = constraints.constrain(child.size * _zoom);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final child = this.child;
    if (child == null) return constraints.smallest;
    return constraints.constrain(
      child.getDryLayout(_inner(constraints)) * _zoom,
    );
  }

  @override
  double computeMinIntrinsicHeight(double width) =>
      (child?.getMinIntrinsicHeight(width / _zoom) ?? 0) * _zoom;

  @override
  double computeMaxIntrinsicHeight(double width) =>
      (child?.getMaxIntrinsicHeight(width / _zoom) ?? 0) * _zoom;

  @override
  double computeMinIntrinsicWidth(double height) =>
      (child?.getMinIntrinsicWidth(height / _zoom) ?? 0) * _zoom;

  @override
  double computeMaxIntrinsicWidth(double height) =>
      (child?.getMaxIntrinsicWidth(height / _zoom) ?? 0) * _zoom;

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    final distance = child?.getDistanceToActualBaseline(baseline);
    return distance == null ? null : distance * _zoom;
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final child = this.child;
    if (child == null) return false;
    return result.addWithPaintTransform(
      transform: _transform,
      position: position,
      hitTest: (result, position) => child.hitTest(result, position: position),
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.multiply(_transform);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    if (_zoom == 1) {
      layer = null;
      context.paintChild(child, offset);
      return;
    }
    layer = context.pushTransform(
      needsCompositing,
      offset,
      _transform,
      (context, offset) => context.paintChild(child, offset),
      oldLayer: layer is TransformLayer ? layer! as TransformLayer : null,
    );
  }
}

/// Two fingers (or a trackpad pinch) on [child] change [zoom], keeping the
/// text between the fingers where it is. [box] is the [ZoomedBox] being
/// zoomed, inside [scroll]'s scroll view. One finger still scrolls and taps.
class PinchZoom extends StatefulWidget {
  const PinchZoom({
    super.key,
    required this.zoom,
    required this.box,
    required this.scroll,
    required this.isPinching,
    required this.onZoomEnd,
    required this.child,
  });

  final ValueNotifier<double> zoom;
  final GlobalKey box;
  final ScrollController scroll;

  /// True while two fingers are down, so the scroll view can stop scrolling.
  final ValueNotifier<bool> isPinching;

  final ValueChanged<double> onZoomEnd;
  final Widget child;

  @override
  State<PinchZoom> createState() => _PinchZoomState();
}

class _PinchZoomState extends State<PinchZoom> {
  final Map<int, Offset> _touches = {};
  bool _isZooming = false;
  bool _isTrackpad = false;
  double _startDistance = 0;
  double _startZoom = 1;

  /// The scroll offset of the zoomed box's top, unchanged by its zoom.
  double _boxTop = 0;

  /// Where in the unzoomed body the fingers started, which stays under them.
  double? _anchor;

  bool get _canZoom =>
      widget.scroll.hasClients && _boxOf() != null && _viewportOf() != null;

  RenderBox? _boxOf() {
    final box = widget.box.currentContext?.findRenderObject();
    return box is RenderBox && box.attached ? box : null;
  }

  RenderBox? _viewportOf() {
    final position = widget.scroll.position;
    final viewport = position.context.notificationContext?.findRenderObject();
    return viewport is RenderBox && viewport.attached ? viewport : null;
  }

  double _focalY(Offset focal) => _viewportOf()!.globalToLocal(focal).dy;

  /// The point of the unzoomed body at [focal], in global coordinates.
  double _unzoomedAt(Offset focal) =>
      (widget.scroll.offset + _focalY(focal) - _boxTop) / widget.zoom.value;

  /// Fingers carry the text they started on along. A trackpad pinch leaves
  /// scrolling on, as a two-finger scroll is the same gesture without a
  /// scale; it keeps the text under the pointer instead.
  void _start(Offset focal, {bool isTouch = true}) {
    if (!_canZoom) return;
    _isZooming = true;
    final box = _boxOf()!;
    final viewport = _viewportOf()!;
    _startZoom = widget.zoom.value;
    _boxTop =
        box.localToGlobal(Offset.zero, ancestor: viewport).dy +
        widget.scroll.offset;
    _anchor = isTouch ? _unzoomedAt(focal) : null;
    if (isTouch) widget.isPinching.value = true;
  }

  /// [focal] is in global coordinates.
  void _update(double scale, Offset focal) {
    if (!_isZooming || !_canZoom) return;
    final from = widget.zoom.value;
    final to = (_startZoom * scale).clamp(minNoteZoom, maxNoteZoom).toDouble();
    final anchor = _anchor;
    if (to == from && anchor == null) return;
    final focalY = _focalY(focal);
    final scroll = widget.scroll;
    final unzoomedY = anchor ?? _unzoomedAt(focal);
    if (from > minNoteZoom && to == minNoteZoom) Haptics.selection();
    widget.zoom.value = to;
    // Out of range for a frame while the body shrinks; the bounce settles it.
    scroll.position.jumpTo(math.max(0, _boxTop + unzoomedY * to - focalY));
  }

  void _end() {
    if (!_isZooming) return;
    _isZooming = false;
    _anchor = null;
    widget.isPinching.value = false;
    final zoom = clampNoteZoom(widget.zoom.value);
    widget.zoom.value = zoom;
    widget.onZoomEnd(zoom);
  }

  double _distance() {
    final points = _touches.values.take(2).toList();
    return (points[0] - points[1]).distance;
  }

  Offset _focal() {
    final points = _touches.values.take(2).toList();
    return (points[0] + points[1]) / 2;
  }

  void _onDown(PointerDownEvent event) {
    if (event.kind != PointerDeviceKind.touch) return;
    _touches[event.pointer] = event.position;
    if (_touches.length == 2) {
      _startDistance = _distance();
      _start(_focal());
    }
  }

  void _onMove(PointerMoveEvent event) {
    if (!_touches.containsKey(event.pointer)) return;
    _touches[event.pointer] = event.position;
    if (_touches.length < 2 || _startDistance <= 0) return;
    _update(_distance() / _startDistance, _focal());
  }

  void _onUp(PointerEvent event) {
    if (_touches.remove(event.pointer) == null) return;
    if (_touches.length < 2) _end();
    if (_touches.length >= 2 && _isZooming) {
      // A third finger lifted: go on from the two still down.
      _startDistance = _distance();
      _startZoom = widget.zoom.value;
      _anchor = _unzoomedAt(_focal());
    }
  }

  void _onPanZoom(PointerPanZoomUpdateEvent event) {
    if (!_isTrackpad) return;
    if (!_isZooming) {
      if ((event.scale - 1).abs() < 0.01) return;
      _start(event.position, isTouch: false);
    }
    _update(event.scale, event.position);
  }

  @override
  void dispose() {
    if (widget.isPinching.value) widget.isPinching.value = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onDown,
      onPointerMove: _onMove,
      onPointerUp: _onUp,
      onPointerCancel: _onUp,
      onPointerPanZoomStart: (_) => _isTrackpad = true,
      onPointerPanZoomUpdate: _onPanZoom,
      onPointerPanZoomEnd: (_) {
        _isTrackpad = false;
        _end();
      },
      child: widget.child,
    );
  }
}
