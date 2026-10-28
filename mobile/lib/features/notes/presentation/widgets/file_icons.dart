import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// The icon for a file of [mimeType] named [name].
IconData fileIconOf(String? mimeType, String name) {
  final mime = mimeType ?? '';
  final lower = name.toLowerCase();
  if (mime == 'application/zip' || lower.endsWith('.zip')) {
    return LucideIcons.fileArchive;
  }
  if (mime.startsWith('text/') ||
      mime == 'application/pdf' ||
      mime.contains('document')) {
    return LucideIcons.fileText;
  }
  if (mime.startsWith('image/')) return LucideIcons.fileImage;
  if (mime.startsWith('video/')) return LucideIcons.fileVideo;
  if (mime.startsWith('audio/')) return LucideIcons.fileAudio;
  return LucideIcons.file;
}

/// "820 KB", "3.4 MB".
String fileSizeLabel(int bytes, String locale) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) {
    return '${NumberFormat.decimalPattern(locale).format((bytes / 1024).round())} KB';
  }
  final megabytes = NumberFormat('0.0', locale).format(bytes / 1024 / 1024);
  return '$megabytes MB';
}
