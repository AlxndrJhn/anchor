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
    // Decode the picture for real, then draw it.
    final logo = find.byType(Image);
    await tester.runAsync(
      () =>
          precacheImage(tester.widget<Image>(logo).image, tester.element(logo)),
    );
    await tester.pump();
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

  testWidgets('the logo is the app icon: slate cloth, the orange top of the '
      'pad and its page', (tester) async {
    final at = await drawLogo(tester, AppTheme.light());

    expect(
      tester.widget<Image>(find.byType(Image)).image,
      isA<ResizeImage>().having(
        (image) => (image.imageProvider as AssetImage).assetName,
        'asset',
        AnchorLogo.asset,
      ),
    );
    final cloth = at(2, 16);
    expect(blue(cloth), greaterThan(red(cloth)), reason: 'slate cloth');
    expect(red(cloth), lessThan(90), reason: 'slate cloth');
    final top = at(16, 7);
    expect(red(top), greaterThan(200), reason: 'orange');
    expect(blue(top), lessThan(110), reason: 'orange');
    final page = at(18, 12);
    expect(red(page), greaterThan(220), reason: 'the light page');
    expect(at(0, 0).a, 0, reason: 'round corners');
  });

  testWidgets('it is the same picture in dark mode', (tester) async {
    final light = await drawLogo(tester, AppTheme.light());
    final lightPixels = [for (var x = 0; x < 32; x += 3) light(x, 16)];
    final dark = await drawLogo(tester, AppTheme.dark());

    expect([for (var x = 0; x < 32; x += 3) dark(x, 16)], lightPixels);
    expect(green(dark(18, 12)), greaterThan(220), reason: 'still a light page');
  });
}
