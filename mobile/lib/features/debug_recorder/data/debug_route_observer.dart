import 'package:flutter/widgets.dart';

import 'debug_recorder_controller.dart';

/// Writes the routes go_router doesn't know of into the debug recording:
/// screens pushed with `Navigator.push`, sheets and dialogs. go_router's own
/// pages are recorded from its location. Does nothing unless debug mode is
/// recording.
class DebugRouteObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _record('push', route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _record('pop', route);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _record('remove', route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null) _record('replace', newRoute);
  }

  static void _record(String action, Route<dynamic> route) {
    final recorder = DebugRecorder.instance;
    if (!recorder.isRecording || route.settings is Page) return;
    recorder.record('navigator', {
      'action': action,
      'route': describeRoute(route),
    });
  }

  /// The route's name, or its kind when it has none.
  static String describeRoute(Route<dynamic> route) =>
      route.settings.name ?? route.runtimeType.toString();
}
