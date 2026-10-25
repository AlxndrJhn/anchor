import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/auth/presentation/auth_controller.dart';
import '../logging/app_logger.dart';
import '../providers/active_user_id_provider.dart';
import '../router/app_router.dart';
import '../router/app_routes.dart';

part 'share_handler.g.dart';

/// A file another app shared, copied into the app's cache.
class SharedFile {
  final String path;
  final String mimeType;
  final String name;

  const SharedFile({
    required this.path,
    required this.mimeType,
    required this.name,
  });
}

/// What arrived through Android's share sheet, to start a note with.
class SharedContent {
  final String? title;
  final String? text;
  final List<SharedFile> files;

  const SharedContent({this.title, this.text, this.files = const []});

  static SharedContent? fromChannel(Object? raw) {
    if (raw is! Map) return null;
    String? clean(Object? value) {
      final text = value is String ? value.trim() : null;
      return text == null || text.isEmpty ? null : text;
    }

    final files = <SharedFile>[
      for (final file in (raw['files'] as List? ?? const []))
        if (file is Map && file['path'] is String)
          SharedFile(
            path: file['path'] as String,
            mimeType: file['mimeType'] as String? ?? '',
            name: file['name'] as String? ?? 'Shared file',
          ),
    ];
    final content = SharedContent(
      title: clean(raw['title']),
      text: clean(raw['text']),
      files: files,
    );
    return content.text == null && files.isEmpty ? null : content;
  }
}

/// Opens a new note for whatever is shared to Anchor ("Share to…"), once
/// someone is signed in.
@Riverpod(keepAlive: true)
class ShareHandler extends _$ShareHandler {
  static const _channel = MethodChannel('anchor/share');

  SharedContent? _pending;

  @override
  void build() {
    if (!Platform.isAndroid) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'shared') await _take();
    });
    ref.onDispose(() => _channel.setMethodCallHandler(null));
    // Shared before the app was running: the activity kept it for us.
    Future.microtask(_take);
    // Shared while sign-in was still settling: open it once that's done.
    ref.listen(authControllerProvider, (_, _) => _flush());
  }

  Future<void> _take() async {
    try {
      _pending =
          SharedContent.fromChannel(
            await _channel.invokeMethod('takeShared'),
          ) ??
          _pending;
    } on PlatformException catch (e) {
      AppLogger.instance.warn('Share', 'Reading the shared content failed: $e');
    }
    _flush();
  }

  void _flush() {
    final shared = _pending;
    if (shared == null) return;
    if (ref.read(authControllerProvider).isLoading) return;
    // No one signed in yet: keep it until someone is.
    if (ref.read(activeUserIdProvider) == null) return;
    _pending = null;
    AppLogger.instance.info(
      'Share',
      'New note from a share: text=${shared.text?.length ?? 0} '
          'files=${shared.files.length}',
    );
    // The nonce makes each share a fresh page, even over an open draft.
    ref
        .read(goRouterProvider)
        .go(
          '/${AppRoutes.noteNew}?share=${DateTime.now().microsecondsSinceEpoch}',
          extra: shared,
        );
  }
}
