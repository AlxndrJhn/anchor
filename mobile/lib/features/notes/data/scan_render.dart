import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image/image.dart' as img;

import '../../../core/files/page_scan.dart';
import '../domain/scan_document.dart';

/// Pictures as plain RGB bytes, three a pixel, row after row.
class Rgb {
  Rgb(this.width, this.height, this.bytes)
    : assert(bytes.length == width * height * 3);

  final int width;
  final int height;
  final Uint8List bytes;

  factory Rgb.of(img.Image picture) {
    final rgb = picture.convert(format: img.Format.uint8, numChannels: 3);
    return Rgb(
      picture.width,
      picture.height,
      Uint8List.fromList(rgb.getBytes(order: img.ChannelOrder.rgb)),
    );
  }

  img.Image toImage() => img.Image.fromBytes(
    width: width,
    height: height,
    bytes: bytes.buffer,
    numChannels: 3,
  );
}

/// The page [page] makes of its [photo] (upright as shown), its longest side
/// at most [maxSide]: straightened, turned and given its colours. The same
/// steps as the web's (web/features/notes/scans.ts), so a page looks alike
/// everywhere.
img.Image renderScanPage(img.Image photo, ScanPage page, {int maxSide = 1200}) {
  // A big photo is shrunk first, averaging its pixels, so a small page
  // isn't grainy.
  var source = photo;
  final longest = math.max(photo.width, photo.height);
  if (longest > maxSide * 2) {
    final scale = maxSide * 2 / longest;
    source = img.copyResize(
      photo,
      width: math.max(1, (photo.width * scale).round()),
      height: math.max(1, (photo.height * scale).round()),
      interpolation: img.Interpolation.average,
    );
  }
  var flat = straightenPage(
    source,
    page.corners ?? wholeCorners,
    maxSide: maxSide,
  );
  if (page.rotate != 0) flat = img.copyRotate(flat, angle: page.rotate);
  final rgb = Rgb.of(flat);
  applyScanLook(rgb, page);
  return rgb.toImage();
}

/// Gives the straightened, turned picture in [rgb] the [page]'s colours,
/// in place.
void applyScanLook(Rgb rgb, ScanPage page) {
  final b = rgb.bytes;
  if (page.profile != ScanProfile.color) {
    evenOutPaper(rgb, page.cleanup / 100);
  }
  switch (page.profile) {
    case ScanProfile.bw:
      final k = 1 + (page.contrast + 25) / 100;
      final cut = 150 + page.threshold;
      for (var i = 0; i < b.length; i += 3) {
        var l = ((b[i] * 77 + b[i + 1] * 150 + b[i + 2] * 29) >> 8).toDouble();
        l = (l - 128) * k + 128 + page.brightness * 1.28;
        final v = l < cut ? 0 : 255;
        b[i] = v;
        b[i + 1] = v;
        b[i + 2] = v;
      }
      return;
    case ScanProfile.whiteboard:
      _saturate(b, 1.6);
      _tone(b, 1 + (page.contrast + 35) / 100, page.brightness);
    case ScanProfile.text:
      _tone(b, 1 + (page.contrast + 25) / 100, page.brightness);
    case ScanProfile.color:
      _tone(b, 1 + page.contrast / 100, page.brightness);
  }
}

/// Lifts the paper's shading towards white by [strength] (0 to 1): each
/// channel is divided by the brightest it is nearby.
void evenOutPaper(Rgb rgb, double strength) {
  if (strength <= 0) return;
  final w = rgb.width, h = rgb.height, b = rgb.bytes;
  final cell = math.max(8, (math.min(w, h) / 40).round());
  final gw = (w / cell).ceil(), gh = (h / cell).ceil();
  // The brightest of each cell, per channel.
  final grid = Float64List(gw * gh * 3);
  for (var y = 0; y < h; y++) {
    final gy = y ~/ cell;
    for (var x = 0; x < w; x++) {
      final g = (gy * gw + x ~/ cell) * 3;
      final i = (y * w + x) * 3;
      for (var c = 0; c < 3; c++) {
        if (b[i + c] > grid[g + c]) grid[g + c] = b[i + c].toDouble();
      }
    }
  }
  // Softened over two cells around, so a letter's cell borrows the paper
  // next to it.
  final soft = Float64List(grid.length);
  for (var gy = 0; gy < gh; gy++) {
    for (var gx = 0; gx < gw; gx++) {
      for (var c = 0; c < 3; c++) {
        var sum = 0.0;
        var n = 0;
        for (
          var yy = math.max(0, gy - 2);
          yy <= math.min(gh - 1, gy + 2);
          yy++
        ) {
          for (
            var xx = math.max(0, gx - 2);
            xx <= math.min(gw - 1, gx + 2);
            xx++
          ) {
            sum += grid[(yy * gw + xx) * 3 + c];
            n++;
          }
        }
        soft[(gy * gw + gx) * 3 + c] = sum / n;
      }
    }
  }
  // Each pixel's paper, between the cell centres around it.
  for (var y = 0; y < h; y++) {
    final fy = ((y + 0.5) / cell - 0.5).clamp(0.0, gh - 1.0);
    final y0 = fy.floor(), y1 = math.min(y0 + 1, gh - 1);
    final ay = fy - y0;
    for (var x = 0; x < w; x++) {
      final fx = ((x + 0.5) / cell - 0.5).clamp(0.0, gw - 1.0);
      final x0 = fx.floor(), x1 = math.min(x0 + 1, gw - 1);
      final ax = fx - x0;
      final i = (y * w + x) * 3;
      for (var c = 0; c < 3; c++) {
        final top =
            soft[(y0 * gw + x0) * 3 + c] * (1 - ax) +
            soft[(y0 * gw + x1) * 3 + c] * ax;
        final bottom =
            soft[(y1 * gw + x0) * 3 + c] * (1 - ax) +
            soft[(y1 * gw + x1) * 3 + c] * ax;
        final paper = top * (1 - ay) + bottom * ay;
        final v = b[i + c];
        final even = math.min(255.0, 255 * v / math.max(paper, 1));
        b[i + c] = (v + (even - v) * strength).round().clamp(0, 255);
      }
    }
  }
}

void _saturate(Uint8List b, double amount) {
  for (var i = 0; i < b.length; i += 3) {
    final l = (b[i] * 77 + b[i + 1] * 150 + b[i + 2] * 29) >> 8;
    for (var c = 0; c < 3; c++) {
      b[i + c] = (l + (b[i + c] - l) * amount).round().clamp(0, 255);
    }
  }
}

/// Contrast [k] around the middle grey, then [brightness] (-100 to 100).
void _tone(Uint8List b, double k, int brightness) {
  final lift = brightness * 1.28;
  final table = Uint8List(256);
  for (var v = 0; v < 256; v++) {
    table[v] = ((v - 128) * k + 128 + lift).round().clamp(0, 255);
  }
  for (var i = 0; i < b.length; i++) {
    b[i] = table[b[i]];
  }
}

/// A photo read by the phone's own decoder, upright as shown, about
/// [longSide] pixels on its longer side at most (null for all of it): much
/// faster than reading it in Dart.
Future<img.Image> readPhoto(String path, {int? longSide}) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(
    await File(path).readAsBytes(),
  );
  final descriptor = await ui.ImageDescriptor.encoded(buffer);
  final longest = math.max(descriptor.width, descriptor.height);
  final scale = longSide == null || longest <= longSide
      ? 1.0
      : longSide / longest;
  final codec = await descriptor.instantiateCodec(
    targetWidth: math.max(1, (descriptor.width * scale).round()),
    targetHeight: math.max(1, (descriptor.height * scale).round()),
  );
  final frame = await codec.getNextFrame();
  codec.dispose();
  descriptor.dispose();
  buffer.dispose();
  final image = frame.image;
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final width = image.width, height = image.height;
  image.dispose();
  if (data == null) throw const FormatException('Not a picture');
  return img.Image.fromBytes(
    width: width,
    height: height,
    bytes: data.buffer,
    numChannels: 4,
  );
}
