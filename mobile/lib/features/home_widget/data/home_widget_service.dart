import 'dart:async';
import 'dart:io';

import 'package:home_widget/home_widget.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/router/pending_launch_route.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/logging/log_tags.dart';
import '../../../core/session/active_user_id_provider.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../notes/presentation/notes_controller.dart';
import 'home_widget_payload.dart';

part 'home_widget_service.g.dart';

const _widgetProviderQualifiedName =
    'com.zhfahim.anchor.widget.NotesWidgetProvider';

@Riverpod(keepAlive: true)
class HomeWidgetSync extends _$HomeWidgetSync {
  Timer? _throttle;
  String? _pending;

  @override
  void build() {
    if (!Platform.isAndroid) return;

    // Wait for auth: a null user while it loads is not a sign-out.
    if (ref.watch(authControllerProvider).isLoading) return;

    final userId = ref.watch(activeUserIdProvider);
    if (userId == null) {
      _push(buildHomeWidgetPayload(const [], loggedIn: false));
      return;
    }

    ref.listen(allActiveNotesProvider, (_, notes) {
      if (notes case AsyncData(:final value)) {
        _schedule(buildHomeWidgetPayload(value, loggedIn: true));
      }
    }, fireImmediately: true);

    ref.onDispose(() {
      _throttle?.cancel();
      _throttle = null;
      _pending = null;
    });
  }

  void _schedule(String payload) {
    if (_throttle != null) {
      _pending = payload;
      return;
    }
    _push(payload);
    _throttle = Timer(const Duration(milliseconds: 300), () {
      _throttle = null;
      final pending = _pending;
      _pending = null;
      if (pending != null) _schedule(pending);
    });
  }

  Future<void> _push(String payload) async {
    try {
      await HomeWidget.saveWidgetData<String>(homeWidgetNotesKey, payload);
      await HomeWidget.updateWidget(
        qualifiedAndroidName: _widgetProviderQualifiedName,
      );
    } catch (e, stack) {
      AppLogger.instance.error(
        LogTags.homeWidget,
        'Failed to push widget data',
        error: e,
        stackTrace: stack,
      );
    }
  }
}

/// Cold-start taps go through `initializeApp`.
@Riverpod(keepAlive: true)
class HomeWidgetLaunchHandler extends _$HomeWidgetLaunchHandler {
  @override
  void build() {
    if (!Platform.isAndroid) return;

    final pending = PendingLaunchRoute(ref);
    final subscription = HomeWidget.widgetClicked.listen((uri) {
      final route = homeWidgetRouteForUri(uri);
      if (route == null) return;
      // Each new-note tap needs its own location to open a fresh draft.
      pending.open(
        route == AppRoutes.widgetNewNote
            ? '$route?tap=${DateTime.now().microsecondsSinceEpoch}'
            : route,
      );
    });
    ref.onDispose(subscription.cancel);
  }
}
