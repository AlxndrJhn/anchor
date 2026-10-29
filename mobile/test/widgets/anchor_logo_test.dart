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
            child: AnchorLogo(size: 32, isRaised: false),
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
      final i = (y * 32 + x) * 4;
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

  testWidgets('the logo is the app icon: an orange top, the page and the '
      'anchor on it', (tester) async {
    final at = await drawLogo(tester, AppTheme.light());

    final top = at(16, 4);
    expect(red(top), greaterThan(230), reason: 'orange');
    expect(blue(top), lessThan(120), reason: 'orange');
    expect(red(at(6, 30)), greaterThan(225), reason: 'the light page');
    expect(at(21, 22), const Color(0xFF2D3142), reason: 'the dark anchor');
    expect(at(0, 0).a, 0, reason: 'round corners');
  });

  testWidgets('in dark mode the page is dark and the anchor light', (
    tester,
  ) async {
    final at = await drawLogo(tester, AppTheme.dark());

    expect(red(at(6, 30)), lessThan(60), reason: 'the dark page');
    expect(green(at(21, 22)), greaterThan(230), reason: 'the light anchor');
    expect(red(at(16, 4)), greaterThan(200), reason: 'still orange');
  });
}
