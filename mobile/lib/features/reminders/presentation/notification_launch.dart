import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../../app/router/app_routes.dart';
import '../data/reminder_actions.dart';

final FlutterLocalNotificationsPlugin notificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// Taps that arrive while the app is running.
final StreamController<String> notificationTaps =
    StreamController<String>.broadcast();

/// Notes whose reminder was marked Done while the app is running.
final StreamController<String> reminderDones =
    StreamController<String>.broadcast();

String? notificationRouteForPayload(String? payload) {
  if (payload == null || payload.isEmpty) return null;
  return AppRoutes.widgetNote(payload);
}

/// Returns the route a cold-start tap asked for. Safe to call before the
/// first frame; does not touch the timezone database.
Future<String?> initializeNotifications() async {
  const settings = InitializationSettings(
    android: AndroidInitializationSettings('ic_stat_reminder'),
    iOS: DarwinInitializationSettings(
      // Permission is asked for at the first reminder.
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    ),
  );

  await notificationsPlugin.initialize(
    settings: settings,
    onDidReceiveNotificationResponse: (response) {
      final noteId = response.payload;
      if (noteId == null || noteId.isEmpty) return;
      if (response.actionId == reminderDoneActionId) {
        reminderDones.add(noteId);
      } else {
        notificationTaps.add(noteId);
      }
    },
    onDidReceiveBackgroundNotificationResponse: onReminderActionInBackground,
  );

  final launch = await notificationsPlugin.getNotificationAppLaunchDetails();
  if (!(launch?.didNotificationLaunchApp ?? false)) return null;
  return notificationRouteForPayload(launch?.notificationResponse?.payload);
}
