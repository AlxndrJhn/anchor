import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:mime/mime.dart';

const _channel = MethodChannel('anchor/files');

/// A folder the user picked, zipped into the app's cache.
class ZippedFolder {
  final String path;

  /// The folder's name, with `.zip`.
  final String name;

  /// How many files are in it, subfolders included.
  final int fileCount;

  const ZippedFolder(this.path, this.name, this.fileCount);
}

/// Lets the user pick a folder with Android's folder screen and zips it,
/// subfolders included. Null when nothing was picked.
Future<ZippedFolder?> pickFolderAsZip() async {
  if (!Platform.isAndroid) return null;
  final raw = await _channel.invokeMapMethod<String, Object?>(
    'pickFolderAsZip',
  );
  if (raw == null) return null;
  return ZippedFolder(
    raw['path'] as String,
    raw['name'] as String,
    raw['files'] as int? ?? 0,
  );
}

/// Opens [path] in an app that can show it. False when no app can.
Future<bool> openWithApp({
  required String path,
  required String name,
  required String mimeType,
}) async {
  if (!Platform.isAndroid) return false;
  return await _channel.invokeMethod<bool>('open', {
        'path': path,
        'name': name,
        'mimeType': mimeType,
      }) ??
      false;
}

/// The MIME type a file name suggests; bytes for one it doesn't.
String mimeTypeFor(String name) =>
    lookupMimeType(name) ?? 'application/octet-stream';
