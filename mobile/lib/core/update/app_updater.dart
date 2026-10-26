import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../logging/app_logger.dart';
import '../storage/preferences_repository.dart';
import 'app_release.dart';

part 'app_updater.g.dart';

const _logTag = 'Update';

/// The fork's releases on GitHub, and Android's installer.
class UpdateSource {
  UpdateSource({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(minutes: 2),
            ),
          );

  // Its own client: the app's sends the user's token, which is for their
  // Anchor server, not GitHub.
  final Dio _dio;

  static const _channel = MethodChannel('anchor/update');

  /// The repository's recent releases, newest first.
  Future<List<Object?>> releases() async {
    final response = await _dio.get<List<Object?>>(
      'https://api.github.com/repos/$updateRepository/releases',
      queryParameters: {'per_page': 30},
      options: Options(headers: {'Accept': 'application/vnd.github+json'}),
    );
    return response.data ?? const [];
  }

  /// Downloads a release's APK into the cache, replacing any older one.
  Future<String> download(
    AppRelease release,
    void Function(double progress) onProgress,
  ) async {
    final dir = Directory('${(await getTemporaryDirectory()).path}/updates');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    dir.createSync(recursive: true);
    final path = '${dir.path}/${release.tag}.apk';
    await _dio.download(
      release.apkUrl,
      path,
      onReceiveProgress: (received, total) {
        final size = total > 0 ? total : release.apkSize;
        if (size > 0) onProgress(received / size);
      },
    );
    final size = File(path).lengthSync();
    if (release.apkSize > 0 && size != release.apkSize) {
      throw StateError('Downloaded $size of ${release.apkSize} bytes');
    }
    return path;
  }

  /// Hands the APK to Android's installer, which asks the user to confirm
  /// (and, the first time, to let Anchor install apps).
  Future<void> install(String path) =>
      _channel.invokeMethod('install', {'path': path});
}

enum UpdateStatus { idle, checking, upToDate, available, downloading, failed }

/// What went wrong, for the words the screen shows.
enum UpdateError { check, download }

class UpdateState {
  const UpdateState({
    this.status = UpdateStatus.idle,
    this.release,
    this.progress = 0,
    this.error,
    this.dismissed = false,
  });

  final UpdateStatus status;

  /// The newest release, when there is one newer than this build.
  final AppRelease? release;

  /// How much of the APK has downloaded, 0 to 1.
  final double progress;

  final UpdateError? error;

  /// The user said "Later" to this release: no banner for it.
  final bool dismissed;

  bool get showBanner =>
      release != null && !dismissed && status != UpdateStatus.checking;

  UpdateState copyWith({
    UpdateStatus? status,
    double? progress,
    UpdateError? error,
    bool? dismissed,
  }) => UpdateState(
    status: status ?? this.status,
    release: release,
    progress: progress ?? this.progress,
    error: error,
    dismissed: dismissed ?? this.dismissed,
  );
}

/// Whether this build can update itself: an Android build from the fork's
/// release workflow.
bool get canSelfUpdate =>
    Platform.isAndroid && installedBuild > 0 && updateRepository.isNotEmpty;

@Riverpod(keepAlive: true)
UpdateSource updateSource(Ref ref) => UpdateSource();

/// This build's number in the fork's releases.
@Riverpod(keepAlive: true)
int installedBuildNumber(Ref ref) => installedBuild;

/// Finds, downloads and installs newer releases of the fork from GitHub.
@Riverpod(keepAlive: true)
class UpdateController extends _$UpdateController {
  @override
  UpdateState build() {
    if (canSelfUpdate) Future.microtask(_checkOnStart);
    return const UpdateState();
  }

  Future<void> _checkOnStart() async {
    final prefs = ref.read(preferencesRepositoryProvider);
    if (await prefs.getCheckForUpdates()) await check();
  }

  /// Looks for a newer release; returns it, or null when there is none or
  /// the check failed (see the state's error).
  Future<AppRelease?> check() async {
    state = state.copyWith(status: UpdateStatus.checking);
    final installed = ref.read(installedBuildNumberProvider);
    try {
      final releases = await ref.read(updateSourceProvider).releases();
      final release = newestRelease(
        releases,
        installed: installed,
        asset: apkAssetForThisPhone(),
      );
      final skipped = await ref
          .read(preferencesRepositoryProvider)
          .getDismissedUpdate();
      AppLogger.instance.info(
        _logTag,
        release == null
            ? 'Build $installed is the newest'
            : 'Build $installed; ${release.tag} is available',
      );
      state = UpdateState(
        status: release == null
            ? UpdateStatus.upToDate
            : UpdateStatus.available,
        release: release,
        dismissed: release != null && skipped == release.build,
      );
      return release;
    } catch (e, stack) {
      AppLogger.instance.warn(
        _logTag,
        'Checking for updates failed',
        error: e,
        stackTrace: stack,
      );
      state = state.copyWith(
        status: UpdateStatus.failed,
        error: UpdateError.check,
      );
      return null;
    }
  }

  /// "Later": no banner for this release; a newer one shows again.
  Future<void> dismiss() async {
    final release = state.release;
    if (release == null) return;
    state = state.copyWith(dismissed: true);
    await ref
        .read(preferencesRepositoryProvider)
        .setDismissedUpdate(release.build);
  }

  /// Downloads the release's APK and opens Android's installer with it.
  Future<void> install() async {
    final release = state.release;
    if (release == null || state.status == UpdateStatus.downloading) return;
    final source = ref.read(updateSourceProvider);
    state = state.copyWith(status: UpdateStatus.downloading, progress: 0);
    try {
      final path = await source.download(
        release,
        (progress) => state = state.copyWith(progress: progress),
      );
      AppLogger.instance.info(_logTag, 'Installing ${release.tag}');
      await source.install(path);
      // The installer takes over; if it's cancelled, it can be opened again.
      state = state.copyWith(status: UpdateStatus.available, progress: 1);
    } catch (e, stack) {
      AppLogger.instance.warn(
        _logTag,
        'Updating to ${release.tag} failed',
        error: e,
        stackTrace: stack,
      );
      state = state.copyWith(
        status: UpdateStatus.failed,
        error: UpdateError.download,
      );
    }
  }
}
