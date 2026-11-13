import 'dart:ui' as ui;

import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/core/widgets/anchor_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<Color Function(int x, int y)> drawLogo(
    WidgetTester tester,
    ThemeData theme,
  ) async {
    const key = ValueKey('logo');
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: const Center(
          child: RepaintBoundary(
            key: key,
            child: AnchorLogo(size: 64, isRaised: false),
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
      final i = (y * 64 + x) * 4;
      return Color.fromARGB(
        pixels.getUint8(i + 3),
        pixels.getUint8(i),
        pixels.getUint8(i + 1),
        pixels.getUint8(i + 2),
      );
    };
  }

  int red(Color color) => (color.r * 255).round();
  int green(Color color) => (color.g * 255).round();
  int blue(Color color) => (color.b * 255).round();

  testWidgets('the logo is the app icon: a note card on deep teal, with an '
      'anchor whose ring is the brass + of Anchor+', (tester) async {
    final at = await drawLogo(tester, AppTheme.light());

    final sea = at(2, 32);
    expect(blue(sea), greaterThan(red(sea) + 60), reason: 'teal');
    expect(green(sea), greaterThan(red(sea) + 40), reason: 'teal');
    expect(at(43, 19), const Color(0xFFF4F1E8), reason: 'the card');
    expect(at(33, 43), const Color(0xFF0B3B4A), reason: 'the teal anchor');
    expect(at(31, 29), const Color(0xFFD9961C), reason: 'the brass +');
    expect(at(0, 0).a, 0, reason: 'round corners');
  });

  testWidgets('in dark mode the sea is darker and the card dimmer', (
    tester,
  ) async {
    final at = await drawLogo(tester, AppTheme.dark());

    final sea = at(2, 32);
    expect(red(sea), lessThan(30), reason: 'the dark sea');
    expect(blue(sea), greaterThan(red(sea) + 40), reason: 'still teal');
    expect(at(43, 19), const Color(0xFFDFE3DF), reason: 'the dimmer card');
    expect(at(31, 29), const Color(0xFFD9961C), reason: 'the brass +');
  });
}
