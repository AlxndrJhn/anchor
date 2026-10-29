import 'dart:ui' as ui;

import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/core/widgets/selection_ring.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// The color within a few steps of [expected], as antialiasing leaves it.
Matcher isNear(Color expected) => predicate<Color>(
  (color) =>
      (color.r - expected.r).abs() < 0.05 &&
      (color.g - expected.g).abs() < 0.05 &&
      (color.b - expected.b).abs() < 0.05 &&
      (color.a - expected.a).abs() < 0.05,
  'near $expected',
);

void main() {
  const gap = Color(0xFF0000FF);
  const ring = Color(0xFFFF0000);
  const key = ValueKey('ring');

  /// The pixels around a 40 square with 12 corners, 8 in from the edges.
  Future<Color Function(int, int)> paintRing(WidgetTester tester) async {
    final radius = BorderRadius.circular(12);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Center(
          child: RepaintBoundary(
            key: key,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: SelectionRing(
                isShown: true,
                borderRadius: radius,
                gap: gap,
                color: ring,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: radius,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(key),
    );
    final pixels = (await tester.runAsync(() async {
      final image = await boundary.toImage();
      return image.toByteData(format: ui.ImageByteFormat.rawRgba);
    }))!;
    return (x, y) {
      final i = (y * 56 + x) * 4;
      return Color.fromARGB(
        pixels.getUint8(i + 3),
        pixels.getUint8(i),
        pixels.getUint8(i + 1),
        pixels.getUint8(i + 2),
      );
    };
  }

  testWidgets('the ring sits outside a gap, each 2 wide', (tester) async {
    final at = await paintRing(tester);

    // Left of the box, along its middle row: box edge at 8.
    expect(at(8, 28), Colors.white);
    expect(at(7, 28), gap);
    expect(at(6, 28), gap);
    expect(at(5, 28), ring);
    expect(at(4, 28), ring);
    expect(at(3, 28).a, 0);
  });

  testWidgets('round corners keep the gap and the ring as wide', (
    tester,
  ) async {
    final at = await paintRing(tester);

    // Along the top left corner's diagonal, from its center at (20, 20): the
    // gap runs 12 to 14 out, the ring 14 to 16.
    expect(at(10, 10), isNear(gap));
    expect(at(9, 9), isNear(ring));
    expect(at(8, 8).a, lessThan(0.5));
  });
}
