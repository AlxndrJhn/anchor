import 'dart:convert';
import 'dart:ui';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../database/app_database.dart';

/// The "Done" button on a reminder notification.
const reminderDoneActionId = 'done';

const reminderDoneAction = AndroidNotificationAction(
  reminderDoneActionId,
  'Done',
  // Handled without opening the app, as in Google Keep.
  showsUserInterface: false,
  cancelNotification: true,
);

/// Marks a reminder done: a one-off reminder is cleared from its note and
/// goes up with the next sync; a repeating one just leaves this occurrence
/// dismissed. Returns whether the note changed.
Future<bool> completeReminder(AppDatabase db, String noteId) async {
  final row = await (db.select(
    db.notes,
  )..where((tbl) => tbl.id.equals(noteId))).getSingleOrNull();
  if (row == null || row.reminderAt == null) return false;
  final repeats =
      row.reminderRecurrence != null && row.reminderRecurrence != 'none';
  if (repeats) return false;

  await (db.update(db.notes)..where((tbl) => tbl.id.equals(noteId))).write(
    const NotesCompanion(
      reminderAt: drift.Value(null),
      reminderRecurrence: drift.Value(null),
      isReminderSynced: drift.Value(false),
    ),
  );
  return true;
}

/// Runs in its own isolate when Done is tapped with the app closed or in the
/// background: opens the signed-in person's notes and completes the reminder.
@pragma('vm:entry-point')
Future<void> onReminderActionInBackground(NotificationResponse response) async {
  if (response.actionId != reminderDoneActionId) return;
  final noteId = response.payload;
  if (noteId == null || noteId.isEmpty) return;

  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  const storage = FlutterSecureStorage();
  final userData = await storage.read(key: 'user_data');
  if (userData == null) return;
  final userId =
      (jsonDecode(userData) as Map<String, dynamic>)['id'] as String?;
  if (userId == null) return;

  final db = AppDatabase(userId);
  try {
    await completeReminder(db, noteId);
  } finally {
    await db.close();
  }
}
