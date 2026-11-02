import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../app/app_bootstrap.dart';
import '../../core/logging/app_logger.dart';
import '../../core/logging/log_tags.dart';
import '../../core/network/dio_provider.dart';
import '../../core/session/active_user_id_provider.dart';
import '../../core/storage/preferences_repository.dart';
import '../../core/theme/custom_theme.dart';
import '../settings/presentation/theme_preferences_controller.dart';

part 'addons.g.dart';

/// An addon installed in Settings › Addons on the web (design/addons.md).
/// Android has no CSS, so of what an addon brings it applies only the theme.
@immutable
class InstalledAddon {
  const InstalledAddon({
    required this.id,
    required this.addonId,
    required this.name,
    required this.version,
    required this.enabled,
    this.description,
    this.author,
    this.theme,
    this.hasStyles = false,
  });

  /// Reads one addon as api/addons lists it; null when it doesn't read.
  static InstalledAddon? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final manifest = json['manifest'];
    if (manifest is! Map<String, dynamic>) return null;
    final contributes = manifest['contributes'];
    final given = contributes is Map<String, dynamic> ? contributes : null;
    final theme = given?['theme'];
    final styles = given?['styles'];
    final id = json['id'];
    final addonId = json['addonId'];
    final name = manifest['name'];
    final version = json['version'];
    if (id is! String ||
        addonId is! String ||
        name is! String ||
        version is! String) {
      return null;
    }
    return InstalledAddon(
      id: id,
      addonId: addonId,
      name: name,
      version: version,
      enabled: json['enabled'] == true,
      description: manifest['description'] as String?,
      author: manifest['author'] as String?,
      theme: theme == null ? null : parseCustomTheme(jsonEncode(theme)).theme,
      hasStyles: styles is List && styles.isNotEmpty,
    );
  }

  /// Reads the list api/addons answers with, leaving out what doesn't read.
  static List<InstalledAddon> listFromJson(Object? json) => [
    if (json is List)
      for (final item in json) ?InstalledAddon.fromJson(item),
  ];

  final String id;
  final String addonId;
  final String name;
  final String version;
  final bool enabled;
  final String? description;
  final String? author;
  final CustomTheme? theme;

  /// Whether it brings CSS, which only the web applies.
  final bool hasStyles;
}

/// The custom theme the app is drawn with: the themes of the addons that are
/// on, in the order they were installed, then the person's own custom theme
/// over them, as on the web.
CustomTheme? withAddonThemes(List<InstalledAddon> addons, CustomTheme? own) {
  final themes = [
    for (final addon in addons)
      if (addon.enabled && addon.theme != null) addon.theme!,
  ];
  if (themes.isEmpty) return own;
  Map<String, Color>? merge(Map<String, Color>? Function(CustomTheme) mode) {
    final colors = <String, Color>{
      for (final theme in [...themes, ?own]) ...?mode(theme),
    };
    return colors.isEmpty ? null : colors;
  }

  return CustomTheme(
    name: own?.name,
    light: merge((theme) => theme.light),
    dark: merge((theme) => theme.dark),
  );
}

@riverpod
AddonsRepository addonsRepository(Ref ref) =>
    AddonsRepository(ref.watch(dioProvider));

class AddonsRepository {
  AddonsRepository(this._dio);

  final Dio _dio;

  /// The addons as JSON, or null from a server without them (upstream
  /// Anchor's).
  Future<List<Object?>?> list() async {
    try {
      final response = await _dio.get<List<Object?>>('/api/addons');
      return response.data ?? const [];
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<Object?> setEnabled(String id, bool enabled) async {
    final response = await _dio.patch<Object?>(
      '/api/addons/$id',
      data: {'enabled': enabled},
    );
    return response.data;
  }
}

/// The signed-in person's addons. Kept on the device, so the app starts in
/// their colours, and fetched again when the app starts and comes back.
@Riverpod(keepAlive: true)
class AddonsController extends _$AddonsController {
  AppLifecycleListener? _lifecycle;
  bool _started = false;

  @override
  List<InstalledAddon> build() {
    final userId = ref.watch(activeUserIdProvider);
    _lifecycle ??= AppLifecycleListener(onResume: refresh);
    ref.onDispose(() {
      _lifecycle?.dispose();
      _lifecycle = null;
    });
    // Whoever signs in next here starts without them.
    if (userId == null) {
      _save(null);
      return const [];
    }
    Future.microtask(refresh);
    if (_started) return const [];
    _started = true;
    return InstalledAddon.listFromJson(
      jsonDecode(ref.read(appBootstrapProvider).addons ?? '[]'),
    );
  }

  Future<void> refresh() async {
    if (ref.read(activeUserIdProvider) == null) return;
    try {
      final json = await ref.read(addonsRepositoryProvider).list();
      state = InstalledAddon.listFromJson(json);
      await _save(json == null ? null : jsonEncode(json));
    } catch (error) {
      // Offline, the addons stay as they were.
      AppLogger.instance.warn(
        LogTags.app,
        'Loading the addons failed',
        error: error,
      );
    }
  }

  /// Turns an addon on or off, here and on every device.
  Future<void> setEnabled(String id, bool enabled) async {
    final json = await ref
        .read(addonsRepositoryProvider)
        .setEnabled(id, enabled);
    final updated = InstalledAddon.fromJson(json);
    if (updated == null) return;
    state = [for (final a in state) a.id == id ? updated : a];
    await refresh();
  }

  Future<void> _save(String? json) =>
      ref.read(preferencesRepositoryProvider).setAddons(json);
}

/// What the app is drawn with: the addons' themes under the custom theme.
@Riverpod(keepAlive: true)
CustomTheme? appCustomTheme(Ref ref) => withAddonThemes(
  ref.watch(addonsControllerProvider),
  ref.watch(customThemeControllerProvider),
);
