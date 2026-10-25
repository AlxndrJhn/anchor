import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/auth/presentation/auth_controller.dart';
import '../providers/active_user_id_provider.dart';
import '../router/app_router.dart';
import '../database/app_database.dart';
import '../network/sync_requester.dart';
import 'notification_launch.dart';
import 'reminder_actions.dart';

part 'reminder_tap_handler.g.dart';

/// Opens the note behind a reminder the user tapped while the app was running.
///
/// Cold-start taps are handled by [initializeApp] instead.
@Riverpod(keepAlive: true)
class ReminderTapHandler extends _$ReminderTapHandler {
  String? _pendingRoute;

  @override
  void build() {
    final subscription = notificationTaps.stream.listen(_queue);
    ref.onDispose(subscription.cancel);
    final dones = reminderDones.stream.listen(_complete);
    ref.onDispose(dones.cancel);

    // A tap can land while auth is transitioning; hold it until that settles.
    ref.listen(authControllerProvider, (_, _) => _flush());
  }

  /// Done tapped on a reminder while the app runs.
  Future<void> _complete(String noteId) async {
    if (ref.read(activeUserIdProvider) == null) return;
    final changed = await completeReminder(
      ref.read(appDatabaseProvider),
      noteId,
    );
    if (changed) scheduleAppSync(trigger: 'ReminderDone');
  }

  void _queue(String noteId) {
    final route = notificationRouteForPayload(noteId);
    if (route == null) return;
    _pendingRoute = route;
    _flush();
  }

  void _flush() {
    final route = _pendingRoute;
    if (route == null) return;
    if (ref.read(authControllerProvider).isLoading) return;

    _pendingRoute = null;
    // No active user: let the normal config/login flow take over.
    if (ref.read(activeUserIdProvider) == null) return;

    ref.read(goRouterProvider).go(route);
  }
}
