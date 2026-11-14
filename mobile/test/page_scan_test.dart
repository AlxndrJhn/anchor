import 'dart:math' as math;
import 'dart:typed_data';

import 'package:anchor/core/files/page_scan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// Whether [p] is inside the convex [quad] (corners in order).
bool _inside(Offset p, List<Offset> quad) {
  double? sign;
  for (var i = 0; i < 4; i++) {
    final a = quad[i], b = quad[(i + 1) % 4];
    final turn = (b.dx - a.dx) * (p.dy - a.dy) - (b.dy - a.dy) * (p.dx - a.dx);
    if (turn == 0) continue;
    sign ??= turn.sign;
    if (turn.sign != sign) return false;
  }
  return true;
}

/// A photo of a page at [corners] (in pixels): light paper with lines of
/// dark "text" on it, on a noisy [table].
Uint8List _photo(
  int width,
  int height,
  List<Offset> corners, {
  int paper = 225,
  int table = 60,
}) {
  final random = math.Random(7);
  final rgba = Uint8List(width * height * 4);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final p = Offset(x + 0.5, y + 0.5);
      var v = _inside(p, corners) ? paper : table;
      // Text: thin dark rows across the page.
      if (v == paper && y % 9 == 0 && x % 13 < 9) v = 50;
      v = (v + random.nextInt(21) - 10).clamp(0, 255);
      final i = (y * width + x) * 4;
      rgba[i] = v;
      rgba[i + 1] = v;
      rgba[i + 2] = v;
      rgba[i + 3] = 255;
    }
  }
  return rgba;
}

void _expectNear(List<Offset> found, List<Offset> want, double tolerance) {
  for (var i = 0; i < 4; i++) {
    expect(
      (found[i] - want[i]).distance,
      lessThan(tolerance),
      reason: 'corner $i: found ${found[i]}, wanted ${want[i]}',
    );
  }
}

void main() {
  test('finds a tilted page on a dark table', () {
    const w = 240, h = 320;
    const corners = [
      Offset(50, 40),
      Offset(200, 70),
      Offset(185, 290),
      Offset(30, 260),
    ];
    final found = findPageCorners(_photo(w, h, corners), w, h);

    expect(found, isNotNull);
    _expectNear(found!, [
      for (final c in corners) Offset(c.dx / w, c.dy / h),
    ], 0.03);
  });

  test('finds a dark page on a light table', () {
    const w = 200, h = 200;
    const corners = [
      Offset(40, 30),
      Offset(170, 40),
      Offset(160, 170),
      Offset(30, 160),
    ];
    final found = findPageCorners(
      _photo(w, h, corners, paper: 40, table: 230),
      w,
      h,
    );

    expect(found, isNotNull);
    _expectNear(found!, [
      for (final c in corners) Offset(c.dx / w, c.dy / h),
    ], 0.04);
  });

  test('finds nothing in a picture without a page', () {
    final random = math.Random(3);
    const w = 120, h = 120;
    final rgba = Uint8List.fromList([
      for (var i = 0; i < w * h; i++) ...[
        random.nextInt(256),
        random.nextInt(256),
        random.nextInt(256),
        255,
      ],
    ]);

    expect(findPageCorners(rgba, w, h), isNull);
  });

  test('puts corners in order whichever way they come', () {
    const want = [
      Offset(0.1, 0.2),
      Offset(0.9, 0.1),
      Offset(0.8, 0.9),
      Offset(0.2, 0.8),
    ];

    expect(orderCorners([want[2], want[0], want[3], want[1]]), want);
  });

  test('a shape folded over itself is not a page', () {
    expect(isPageShape(wholeCorners), isTrue);
    expect(
      isPageShape(const [
        Offset(0, 0),
        Offset(1, 1),
        Offset(1, 0),
        Offset(0, 1),
      ]),
      isFalse,
    );
  });

  test('straightening a tilted page brings each corner to its place', () {
    // A page split into four colored quarters, photographed at a slant.
    const w = 400, h = 300;
    const corners = [
      Offset(60, 40),
      Offset(340, 70),
      Offset(310, 270),
      Offset(80, 240),
    ];
    final picture = img.Image(width: w, height: h);
    final mid = [
      for (var i = 0; i < 4; i++) (corners[i] + corners[(i + 1) % 4]) / 2,
    ];
    final center = (mid[0] + mid[2]) / 2;
    final quarters = [
      ([corners[0], mid[0], center, mid[3]], img.ColorRgb8(255, 0, 0)),
      ([mid[0], corners[1], mid[1], center], img.ColorRgb8(0, 255, 0)),
      ([center, mid[1], corners[2], mid[2]], img.ColorRgb8(0, 0, 255)),
      ([mid[3], center, mid[2], corners[3]], img.ColorRgb8(255, 255, 0)),
    ];
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final p = Offset(x + 0.5, y + 0.5);
        for (final (quad, color) in quarters) {
          if (_inside(p, quad)) picture.setPixel(x, y, color);
        }
      }
    }

    final flat = straightenPage(picture, [
      for (final c in corners) Offset(c.dx / w, c.dy / h),
    ]);

    // As wide and tall as the page's longest sides.
    expect(flat.width, closeTo(282, 2));
    expect(flat.height, closeTo(202, 2));
    img.Color at(double u, double v) =>
        flat.getPixel((u * flat.width).round(), (v * flat.height).round());
    expect(at(0.2, 0.2).r, 255);
    expect(at(0.2, 0.2).g, 0);
    expect(at(0.8, 0.2).g, 255);
    expect(at(0.8, 0.2).r, 0);
    expect(at(0.8, 0.8).b, 255);
    expect(at(0.2, 0.8).r, 255);
    expect(at(0.2, 0.8).g, 255);
  });

  test('straightening to the whole picture keeps it as it was', () {
    final picture = img.Image(width: 30, height: 20);
    picture.setPixelRgb(3, 4, 255, 0, 0);

    final same = straightenPage(picture, wholeCorners);

    expect(same.width, 30);
    expect(same.height, 20);
    expect(same.getPixel(3, 4).r, 255);
  });
}
