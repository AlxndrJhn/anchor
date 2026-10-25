import 'dart:io' show Directory, File, Platform;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

import '../logging/app_logger.dart';
import '../widgets/app_snackbar.dart';

/// How a save went: picked a place, cancelled, or fell back to [path].
sealed class SaveResult {
  const SaveResult();
}

class SavedWithPicker extends SaveResult {
  const SavedWithPicker();
}

class SavedTo extends SaveResult {
  final String path;
  const SavedTo(this.path);
}

class SaveCancelled extends SaveResult {
  const SaveCancelled();
}

class SaveFailed extends SaveResult {
  final Object error;
  const SaveFailed(this.error);
}

/// Saves [bytes] as [filename] where the user picks with the system's save
/// screen. Some devices have no such screen the app can reach; then the file
/// goes straight into the shared Download folder (or the app's own folder).
Future<SaveResult> saveToDevice({
  required String filename,
  required Uint8List bytes,
  required String tag,
}) async {
  try {
    final picked = await FilePicker.saveFile(
      dialogTitle: 'Save $filename',
      fileName: filename,
      bytes: bytes,
    );
    return picked == null ? const SaveCancelled() : const SavedWithPicker();
  } catch (e) {
    AppLogger.instance.warn(
      tag,
      'Save picker failed, saving to Downloads instead: $e',
    );
    if (!Platform.isAndroid) return SaveFailed(e);
    final folders = <Directory?>[
      Directory('/storage/emulated/0/Download'),
      await getExternalStorageDirectory(),
    ];
    for (final folder in folders) {
      if (folder == null) continue;
      try {
        final file = File('${folder.path}/$filename');
        await file.writeAsBytes(bytes, flush: true);
        return SavedTo(file.path);
      } catch (e, st) {
        AppLogger.instance.error(
          tag,
          'Saving $filename to ${folder.path} failed',
          error: e,
          stackTrace: st,
        );
      }
    }
    return SaveFailed(e);
  }
}

/// Saves the file at [sourcePath] as [filename] and says how it went.
Future<void> saveFileToDevice(
  BuildContext context, {
  required String sourcePath,
  required String filename,
  required String tag,
}) async {
  final SaveResult result;
  try {
    final bytes = await File(sourcePath).readAsBytes();
    result = await saveToDevice(filename: filename, bytes: bytes, tag: tag);
  } catch (e) {
    if (context.mounted) {
      AppSnackbar.showError(context, message: 'Couldn’t read $filename');
    }
    return;
  }
  if (!context.mounted) return;
  switch (result) {
    case SavedWithPicker():
      AppSnackbar.showSuccess(context, message: 'Saved $filename');
    case SavedTo(:final path):
      AppSnackbar.showSuccess(context, message: 'Saved to $path');
    case SaveFailed():
      AppSnackbar.showError(context, message: 'Couldn’t save $filename');
    case SaveCancelled():
      break;
  }
}
