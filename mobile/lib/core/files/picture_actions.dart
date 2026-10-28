import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';

import '../logging/app_logger.dart';
import '../widgets/app_snackbar.dart';
import 'device_files.dart';

/// Hands the picture at [path] to another app through Android's share sheet.
Future<void> sharePicture({required String path, required String name}) async {
  try {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(path, name: name, mimeType: mimeTypeFor(name))],
      ),
    );
  } catch (e) {
    AppLogger.instance.warn('Pictures', 'Sharing $name failed: $e');
  }
}

/// Puts the picture at [path] on the clipboard and says how that went.
Future<void> copyPicture(
  BuildContext context, {
  required String path,
  required String name,
}) async {
  try {
    if (!await copyImageToClipboard(path: path, name: name)) return;
    if (context.mounted) {
      AppSnackbar.showSuccess(context, message: 'Picture copied');
    }
  } catch (e) {
    AppLogger.instance.warn('Pictures', 'Copying $name failed: $e');
    if (context.mounted) {
      AppSnackbar.showError(context, message: 'Couldn’t copy the picture');
    }
  }
}
