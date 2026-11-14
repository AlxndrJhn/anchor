import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/scan_document.dart';
import 'scan_render.dart';

final _making = <String, Future<String>>{};

/// The page [page] makes of the photo at [photoPath], at most [maxSide]
/// pixels long, as a JPEG in the app's cache; made off the UI thread once
/// and kept for as long as its settings stay the same.
Future<String> scanPreview(
  String photoPath,
  ScanPage page, {
  int maxSide = 600,
}) {
  final key = sha1
      .convert(utf8.encode('$photoPath|${page.renderKey}|$maxSide'))
      .toString();
  return _making[key] ??=
      _make(
        photoPath,
        page,
        maxSide,
        key,
        // A block: the removed future returned here would be waited for, and
        // it's this one.
      ).whenComplete(() {
        _making.remove(key);
      });
}

Future<String> _make(
  String photoPath,
  ScanPage page,
  int maxSide,
  String key,
) async {
  final dir = Directory(
    p.join((await getTemporaryDirectory()).path, 'scan-previews'),
  );
  final out = p.join(dir.path, '$key.jpg');
  if (File(out).existsSync()) return out;
  await dir.create(recursive: true);
  final photo = await readPhoto(photoPath, longSide: maxSide * 2);
  await Isolate.run(() {
    final rendered = renderScanPage(photo, page, maxSide: maxSide);
    // Written aside first, so a half-written file is never shown.
    final part = '$out.part';
    File(part).writeAsBytesSync(img.encodeJpg(rendered, quality: 85));
    File(part).renameSync(out);
  });
  return out;
}
