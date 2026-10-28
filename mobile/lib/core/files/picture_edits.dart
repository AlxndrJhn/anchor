import 'dart:io';
import 'dart:isolate';
import 'dart:ui' show Rect;

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// A change made to a picture: it's written anew as a JPEG.
sealed class PictureEdit {
  const PictureEdit();
}

/// Left and right swapped.
class MirrorHorizontally extends PictureEdit {
  const MirrorHorizontally();
}

/// Top and bottom swapped.
class MirrorVertically extends PictureEdit {
  const MirrorVertically();
}

/// Only [area] kept, as shares (0 to 1) of the picture's width and height.
class CropTo extends PictureEdit {
  final Rect area;
  const CropTo(this.area);
}

/// Writes the picture at [path] with [edit] made to it into a new file in
/// the app's cache, and returns its path. The work happens off the UI
/// thread; a big photo takes a moment.
Future<String> editPicture(String path, PictureEdit edit) async {
  final dir = Directory(p.join((await getTemporaryDirectory()).path, 'edits'));
  await dir.create(recursive: true);
  final out = p.join(
    dir.path,
    '${p.basenameWithoutExtension(path)}-${DateTime.now().millisecondsSinceEpoch}.jpg',
  );
  // Only plain values cross into the isolate.
  final area = edit is CropTo ? edit.area : null;
  final mirror = switch (edit) {
    MirrorHorizontally() => img.FlipDirection.horizontal,
    MirrorVertically() => img.FlipDirection.vertical,
    CropTo() => null,
  };
  await Isolate.run(() {
    final decoded = img.decodeImage(File(path).readAsBytesSync());
    if (decoded == null) throw const FormatException('Not a picture');
    // As it's shown: the camera's rotation is in its EXIF data.
    var picture = img.bakeOrientation(decoded);
    if (mirror != null) {
      picture = img.flip(picture, direction: mirror);
    } else if (area != null) {
      picture = cropShare(picture, area);
    }
    File(out).writeAsBytesSync(img.encodeJpg(picture, quality: 92));
  });
  return out;
}

/// [picture] cut to [area], given as shares of its width and height.
img.Image cropShare(img.Image picture, Rect area) {
  final w = picture.width, h = picture.height;
  final left = (area.left.clamp(0.0, 1.0) * w).round();
  final top = (area.top.clamp(0.0, 1.0) * h).round();
  final right = (area.right.clamp(0.0, 1.0) * w).round();
  final bottom = (area.bottom.clamp(0.0, 1.0) * h).round();
  return img.copyCrop(
    picture,
    x: left,
    y: top,
    width: (right - left).clamp(1, w - left),
    height: (bottom - top).clamp(1, h - top),
  );
}
