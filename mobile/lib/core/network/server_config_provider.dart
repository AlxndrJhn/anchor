import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../logging/app_logger.dart';
import '../logging/log_tags.dart';
import '../storage/preferences_repository.dart';
import '../storage/secure_storage_provider.dart';
import '../storage/storage_keys.dart';
import 'server_address.dart';
import 'server_headers.dart';

part 'server_config_provider.g.dart';

@Riverpod(keepAlive: true)
class ServerConfig extends _$ServerConfig {
  @override
  Future<String?> build() async {
    return ref.watch(secureStorageProvider).read(key: StorageKeys.serverUrl);
  }

  Future<void> setServerUrl(String url) async {
    final normalizedUrl = normalizeServerUrl(url) ?? url.trim();
    await ref
        .read(secureStorageProvider)
        .write(key: StorageKeys.serverUrl, value: normalizedUrl);
    state = AsyncData(normalizedUrl);
  }

  /// Keeps the notes on this device only, and opens on them from now on.
  Future<void> useWithoutServer() async {
    final storage = ref.read(secureStorageProvider);
    await storage.write(key: StorageKeys.localOnly, value: 'true');
    await storage.delete(key: StorageKeys.serverUrl);
    state = const AsyncData(null);
  }
}

@Riverpod(keepAlive: true)
String? serverUrl(Ref ref) {
  final config = ref.watch(serverConfigProvider);
  return config.value;
}

@Riverpod(keepAlive: true)
class AllowSelfSignedCert extends _$AllowSelfSignedCert {
  @override
  Future<bool> build() async {
    try {
      return await ref
          .watch(preferencesRepositoryProvider)
          .getAllowSelfSignedCert();
    } catch (error) {
      AppLogger.instance.warn(
        LogTags.settings,
        'Reading the self-signed setting failed',
        error: error,
      );
      return false;
    }
  }

  Future<void> toggle(bool value) async {
    state = AsyncData(value);
    try {
      await ref
          .read(preferencesRepositoryProvider)
          .setAllowSelfSignedCert(value);
    } catch (error) {
      AppLogger.instance.warn(
        LogTags.settings,
        'Saving the self-signed setting failed',
        error: error,
      );
    }
  }
}

/// The extra headers saved with a server, if any.
@Riverpod(keepAlive: true)
class SavedServerHeaders extends _$SavedServerHeaders {
  @override
  Future<ServerHeaders?> build() async {
    try {
      return await ref.watch(preferencesRepositoryProvider).getServerHeaders();
    } catch (error) {
      AppLogger.instance.warn(
        LogTags.settings,
        'Reading the server headers failed',
        error: error,
      );
      return null;
    }
  }

  /// Blank [text] forgets them.
  Future<void> save(String server, String text) async {
    final headers = text.trim().isEmpty
        ? null
        : ServerHeaders(server: server, text: text);
    state = AsyncData(headers);
    try {
      await ref.read(preferencesRepositoryProvider).setServerHeaders(headers);
    } catch (error) {
      AppLogger.instance.warn(
        LogTags.settings,
        'Saving the server headers failed',
        error: error,
      );
    }
  }
}

/// The extra headers to send to the server in use.
@Riverpod(keepAlive: true)
Map<String, String> serverHeaders(Ref ref) =>
    ref
        .watch(savedServerHeadersProvider)
        .value
        ?.forServer(ref.watch(serverUrlProvider)) ??
    const {};
