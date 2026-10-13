import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// [marker] must be deleted with the app.
Future<void> clearStorageOnNewInstall(
  FlutterSecureStorage storage,
  File marker,
) async {
  if (await marker.exists()) return;
  await storage.deleteAll();
  await marker.create(recursive: true);
}
