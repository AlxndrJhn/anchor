import 'dart:ui' as ui;

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'picture_aspect_ratios.g.dart';

/// Width over height of each picture measured so far.
class PictureAspectRatios {
  final Map<String, double> _shapes = {};

  double? of(String attachmentId) => _shapes[attachmentId];

  /// Reads the size from the file's header without decoding the image.
  Future<double> measure(String attachmentId, String file) async {
    final known = _shapes[attachmentId];
    if (known != null) return known;
    try {
      final buffer = await ui.ImmutableBuffer.fromFilePath(file);
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      final shape = descriptor.width / descriptor.height;
      descriptor.dispose();
      buffer.dispose();
      return _shapes[attachmentId] = shape;
    } catch (_) {
      return 1;
    }
  }
}

@Riverpod(keepAlive: true)
PictureAspectRatios pictureAspectRatios(Ref ref) => PictureAspectRatios();
