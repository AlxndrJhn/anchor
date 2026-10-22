import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/router/pending_launch_route.dart';
import 'notification_launch.dart';

part 'reminder_tap_handler.g.dart';

/// Cold-start taps go through `initializeApp`.
@Riverpod(keepAlive: true)
class ReminderTapHandler extends _$ReminderTapHandler {
  @override
  void build() {
    final pending = PendingLaunchRoute(ref);
    final subscription = notificationTaps.stream.listen((noteId) {
      final route = notificationRouteForPayload(noteId);
      if (route != null) pending.open(route);
    });
    ref.onDispose(subscription.cancel);
  }
}
