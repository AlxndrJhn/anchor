import 'dart:ui' show Rect;

import 'package:anchor/core/files/picture_edits.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test('cropping keeps the part given as shares of the picture', () {
    final picture = img.Image(width: 200, height: 100);
    // A red pixel where the kept part starts.
    picture.setPixelRgb(50, 25, 255, 0, 0);

    final cropped = cropShare(
      picture,
      const Rect.fromLTRB(0.25, 0.25, 0.75, 1),
    );

    expect(cropped.width, 100);
    expect(cropped.height, 75);
    expect(cropped.getPixel(0, 0).r, 255);
  });

  test('a frame past the edges is held to the picture', () {
    final cropped = cropShare(
      img.Image(width: 10, height: 10),
      const Rect.fromLTRB(-1, 0.5, 2, 3),
    );

    expect(cropped.width, 10);
    expect(cropped.height, 5);
  });
}
