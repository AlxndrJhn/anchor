import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Saves [bytes] as [name] where the person picks on the phone's save
/// screen. Phones without one the app can reach get the share sheet instead.
///
/// True once saved; false when cancelled or handed to the share sheet.
Future<bool> saveBytesToDevice({
  required String name,
  required Uint8List bytes,
  required String dialogTitle,
  String? mimeType,
}) async {
  try {
    final saved = await FilePicker.saveFile(
      dialogTitle: dialogTitle,
      fileName: name,
      bytes: bytes,
    );
    return saved != null;
  } on PlatformException catch (error) {
    if (error.code != 'explorer_not_found') rethrow;
    final file = File(p.join((await getTemporaryDirectory()).path, name));
    await file.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path, mimeType: mimeType)]),
    );
    return false;
  }
}

/// [saveBytesToDevice] for a file already on the phone.
Future<bool> saveFileToDevice({
  required String path,
  required String name,
  required String dialogTitle,
  String? mimeType,
}) async => saveBytesToDevice(
  name: name,
  bytes: await File(path).readAsBytes(),
  dialogTitle: dialogTitle,
  mimeType: mimeType,
);
