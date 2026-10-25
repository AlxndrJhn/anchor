import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/router/pending_launch_route.dart';
import '../../../core/database/app_database.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/logging/log_tags.dart';
import '../../../core/network/sync_requester.dart';
import '../../../core/session/active_user_id_provider.dart';
import '../data/reminder_actions.dart';
import 'notification_launch.dart';

part 'reminder_tap_handler.g.dart';

/// Opens the note behind a tapped reminder, and completes one whose Done was
/// tapped while the app runs. Cold-start taps go through `initializeApp`.
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
    final dones = reminderDones.stream.listen(_complete);
    ref.onDispose(dones.cancel);
  }

  Future<void> _complete(String noteId) async {
    if (ref.read(activeUserIdProvider) == null) return;
    final changed = await completeReminder(
      ref.read(appDatabaseProvider),
      noteId,
    );
    AppLogger.instance.info(
      LogTags.notifications,
      'reminder done id=$noteId cleared=$changed',
    );
    if (changed) scheduleAppSync(trigger: 'ReminderDone');
  }
}
