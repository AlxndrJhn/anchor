import 'dart:io';

import 'package:flutter/services.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/logging/log_tags.dart';

typedef UploadablePhoto = ({String path, String mime});

/// The server takes JPEG, PNG, WebP and GIF pictures. Other photos, such as
/// HEIC from Android phones, are turned into JPEG on the phone.
abstract final class PhotoFiles {
  static const _channel = MethodChannel('anchor/photos');

  /// Null when the photo can't be read or turned into JPEG.
  static Future<UploadablePhoto?> uploadable(String file) async {
    final mime = mimeOf(await _head(file));
    if (mime != null) return (path: file, mime: mime);
    try {
      final jpeg = await _channel.invokeMethod<String>('toJpeg', {
        'path': file,
      });
      return jpeg == null ? null : (path: jpeg, mime: 'image/jpeg');
    } on MissingPluginException {
      return null;
    } on PlatformException catch (e) {
      AppLogger.instance.warn(
        LogTags.attachments,
        'toJpeg failed: ${e.code} ${e.message}',
      );
      return null;
    }
  }

  /// The type of a picture the server takes, from its first bytes.
  static String? mimeOf(List<int> head) {
    bool has(List<int> bytes, [int at = 0]) {
      if (head.length < at + bytes.length) return false;
      for (var i = 0; i < bytes.length; i++) {
        if (head[at + i] != bytes[i]) return false;
      }
      return true;
    }

    if (has(const [0xFF, 0xD8, 0xFF])) return 'image/jpeg';
    if (has(const [0x89, 0x50, 0x4E, 0x47])) return 'image/png';
    if (has('GIF8'.codeUnits)) return 'image/gif';
    if (has('RIFF'.codeUnits) && has('WEBP'.codeUnits, 8)) {
      return 'image/webp';
    }
    return null;
  }

  static Future<List<int>> _head(String file) async {
    try {
      final handle = await File(file).open();
      try {
        return await handle.read(12);
      } finally {
        await handle.close();
      }
    } on FileSystemException {
      return const [];
    }
  }
}
