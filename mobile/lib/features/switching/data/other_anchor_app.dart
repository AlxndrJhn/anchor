import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/storage/preferences_repository.dart';

part 'other_anchor_app.g.dart';

/// The Anchor app someone is switching from, still installed: the official
/// one, or this fork under its old id. Android keeps each app's notes to
/// itself, so its notes only get here through the server.
@immutable
class OtherAnchorApp {
  const OtherAnchorApp({required this.package, required this.label});

  final String package;

  /// Its name on the home screen.
  final String label;

  static const _channel = MethodChannel('anchor/other_app');

  static Future<OtherAnchorApp?> find() async {
    if (!Platform.isAndroid) return null;
    try {
      final found = await _channel.invokeMapMethod<String, String>('find');
      if (found == null) return null;
      return OtherAnchorApp(package: found['package']!, label: found['label']!);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  Future<bool> open() async =>
      await _channel.invokeMethod<bool>('open', {'package': package}) ?? false;

  /// Its page in Android's settings, where it can be uninstalled.
  Future<bool> showDetails() async =>
      await _channel.invokeMethod<bool>('showDetails', {'package': package}) ??
      false;

  @override
  bool operator ==(Object other) =>
      other is OtherAnchorApp &&
      other.package == package &&
      other.label == label;

  @override
  int get hashCode => Object.hash(package, label);
}

/// The other Anchor app, looked for again whenever this one comes back to
/// the front, so uninstalling it takes its notices away.
@Riverpod(keepAlive: true)
class OtherAnchorAppController extends _$OtherAnchorAppController {
  @override
  Future<OtherAnchorApp?> build() {
    final lifecycle = AppLifecycleListener(onResume: _refresh);
    ref.onDispose(lifecycle.dispose);
    return OtherAnchorApp.find();
  }

  Future<void> _refresh() async {
    state = AsyncData(await OtherAnchorApp.find());
  }
}

/// Whether the user said they'd keep the other app, so the "you can
/// uninstall it" banner stays away.
@Riverpod(keepAlive: true)
class OtherAppDismissed extends _$OtherAppDismissed {
  @override
  Future<bool> build() =>
      ref.read(preferencesRepositoryProvider).getOtherAppDismissed();

  Future<void> dismiss() async {
    state = const AsyncData(true);
    await ref.read(preferencesRepositoryProvider).setOtherAppDismissed();
  }
}
