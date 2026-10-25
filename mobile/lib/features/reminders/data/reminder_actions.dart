import 'dart:convert';
import 'dart:ui';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/database/app_database.dart';
import '../../../core/storage/storage_keys.dart';
import '../../../l10n/app_localizations.dart';
import '../../notes/data/local/note_rows.dart';
import '../../notes/domain/note.dart';

/// The "Done" button on a reminder notification.
const reminderDoneActionId = 'done';

AndroidNotificationAction reminderDoneAction(AppLocalizations l10n) =>
    AndroidNotificationAction(
      reminderDoneActionId,
      l10n.reminderDone,
      // Handled without opening the app, as in Google Keep.
      showsUserInterface: false,
      cancelNotification: true,
    );

/// Marks a reminder done: a one-off reminder is cleared from its note and
/// goes up with the next sync, as setting no reminder does; a repeating one
/// just leaves this occurrence dismissed. Returns whether the note changed.
Future<bool> completeReminder(AppDatabase db, String noteId) async {
  return db.transaction(() async {
    final row = await db.noteRow(noteId);
    if (row == null || row.reminderAt == null) return false;
    final recurrence = ReminderRecurrence.fromString(row.reminderRecurrence);
    if (recurrence != ReminderRecurrence.none) return false;
    await db.writeNote(
      noteId,
      const NotesCompanion(
        reminderAt: drift.Value(null),
        reminderRecurrence: drift.Value(null),
        isReminderSynced: drift.Value(false),
      ),
    );
    return true;
  });
}

/// Runs in its own isolate when Done is tapped with the app closed or in the
/// background: opens the signed-in person's notes and completes the reminder.
/// The change goes up with the app's next sync.
@pragma('vm:entry-point')
Future<void> onReminderActionInBackground(NotificationResponse response) async {
  if (response.actionId != reminderDoneActionId) return;
  final noteId = response.payload;
  if (noteId == null || noteId.isEmpty) return;

  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  const storage = FlutterSecureStorage();
  final userData = await storage.read(key: StorageKeys.userData);
  if (userData == null) return;
  final String? userId;
  try {
    userId = (jsonDecode(userData) as Map<String, dynamic>)['id'] as String?;
  } catch (_) {
    return;
  }
  if (userId == null) return;

  final db = AppDatabase(userId);
  try {
    await completeReminder(db, noteId);
  } finally {
    await db.close();
  }
}
