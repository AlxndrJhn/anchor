import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

/// Must match the web's `markerStroke`, seeds included.
abstract final class MarkerStroke {
  static final Map<String, _Stroke> _cache = {};

  /// [key] and [index] seed the stroke. [openLeft] and [openRight] are false
  /// where a clip cuts the mark off.
  static void paint(
    Canvas canvas,
    Rect line,
    Color color, {
    required String key,
    required int index,
    required double fontSize,
    bool openLeft = true,
    bool openRight = true,
  }) {
    if (line.width < 3) return;
    final overhangLeft = openLeft ? fontSize * 0.38 : 0.0;
    final overhangRight = openRight ? fontSize * 0.5 : 0.0;
    final width = (line.width + overhangLeft + overhangRight).roundToDouble();
    final height = line.height.roundToDouble();
    final seed = _hash('$key|$index');
    final cacheKey = '$seed|$width|$height';
    final stroke = _cache.putIfAbsent(
      cacheKey,
      () => _Stroke.build(width, height, seed, overhangLeft, overhangRight),
    );
    if (_cache.length > 600) _cache.clear();
    canvas
      ..save()
      ..translate(line.left - overhangLeft, line.top);
    final paint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(stroke.x0, 0),
        Offset(stroke.x1, 0),
        [
          for (final stop in stroke.stops)
            color.withValues(alpha: color.a * stop.$2),
        ],
        [for (final stop in stroke.stops) stop.$1],
      );
    canvas
      ..drawPath(stroke.path, paint)
      ..restore();
  }

  /// FNV-1a, as the web's `strHash`.
  static int _hash(String text) {
    var hash = 2166136261;
    for (final unit in text.codeUnits) {
      hash = ((hash ^ unit) * 16777619) & 0xFFFFFFFF;
    }
    return hash;
  }
}

class _Stroke {
  _Stroke(this.path, this.x0, this.x1, this.stops);

  final Path path;
  final double x0;
  final double x1;
  final List<(double, double)> stops;

  static _Stroke build(
    double width,
    double height,
    int seed,
    double overhangLeft,
    double overhangRight,
  ) {
    final random = _Mulberry32(seed);
    double randomBetween(double min, double max) =>
        min + random.next() * (max - min);
    final top = height * randomBetween(0.27, 0.33);
    final bottom = height * randomBetween(0.98, 1.04);
    final slant = (bottom - top) * 0.4;
    final x0 = randomBetween(0, overhangLeft * 0.45);
    final x1 = width - randomBetween(0, overhangRight * 0.35);
    final rise =
        randomBetween(-0.2, 1) * (width * 0.012 < 2.6 ? width * 0.012 : 2.6);
    double driftAt(double x) =>
        -(x - x0) / ((x1 - x0) < 1 ? 1 : (x1 - x0)) * rise;
    final points = <Offset>[];
    for (var x = x0 + slant; x < x1; x += 9) {
      points.add(Offset(x, top + driftAt(x) + randomBetween(-0.35, 0.35)));
    }
    points
      ..add(Offset(x1, top + driftAt(x1)))
      ..add(Offset(x1 - slant, bottom + driftAt(x1 - slant)));
    for (var x = x1 - slant - 9; x > x0; x -= 9) {
      points.add(Offset(x, bottom + driftAt(x) + randomBetween(-0.35, 0.35)));
    }
    points.add(Offset(x0, bottom + driftAt(x0)));
    final stops = <(double, double)>[(0, 0.84), (0.05, 0.97)];
    for (var k = 1; k <= 3; k++) {
      stops.add((0.05 + k * 0.22, randomBetween(0.92, 1)));
    }
    stops
      ..add((0.95, 0.97))
      ..add((1, 0.86));
    final path = Path()..addPolygon(points, true);
    return _Stroke(path, x0, x1, stops);
  }
}

/// mulberry32, as the web's `seeded`.
class _Mulberry32 {
  _Mulberry32(int seed) : _state = seed & 0xFFFFFFFF;

  int _state;

  static int _imul(int a, int b) =>
      ((a & 0xFFFFFFFF) * (b & 0xFFFFFFFF)) & 0xFFFFFFFF;

  double next() {
    _state = (_state + 0x6D2B79F5) & 0xFFFFFFFF;
    var t = _imul(_state ^ (_state >> 15), 1 | _state);
    t = ((t + _imul(t ^ (t >> 7), 61 | t)) & 0xFFFFFFFF) ^ t;
    return ((t ^ (t >> 14)) & 0xFFFFFFFF) / 4294967296;
  }
}
