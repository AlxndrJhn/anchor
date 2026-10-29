import 'dart:io';

import 'package:anchor/core/storage/clear_storage_on_new_install.dart';
import 'package:anchor/core/storage/storage_keys.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const storage = FlutterSecureStorage();
  late Directory folder;
  late File marker;

  setUp(() async {
    folder = await Directory.systemTemp.createTemp('install');
    marker = File('${folder.path}/installed');
    FlutterSecureStorage.setMockInitialValues({
      StorageKeys.serverUrl: 'https://notes.example.com',
      StorageKeys.accessToken: 'token',
      StorageKeys.themeMode: 'dark',
      StorageKeys.notificationsAsked: 'true',
    });
  });

  tearDown(() => folder.delete(recursive: true));

  test('a new install starts signed out with default settings', () async {
    await clearStorageOnNewInstall(storage, marker);

    expect(await storage.readAll(), isEmpty);
  });

  test('the same install keeps its storage', () async {
    await clearStorageOnNewInstall(storage, marker);
    await storage.write(key: StorageKeys.accessToken, value: 'token');

    await clearStorageOnNewInstall(storage, marker);

    expect(await storage.read(key: StorageKeys.accessToken), 'token');
  });
}
