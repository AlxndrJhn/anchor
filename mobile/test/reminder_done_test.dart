import 'package:anchor/core/database/app_database.dart';
import 'package:anchor/features/reminders/data/reminder_actions.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });
  tearDown(() => db.close());

  Future<void> addNote(String id, String? recurrence) => db
      .into(db.notes)
      .insert(
        NotesCompanion.insert(
          id: id,
          title: id,
          reminderAt: const Value('2030-01-01T09:00'),
          reminderRecurrence: Value(recurrence),
          isReminderSynced: const Value(true),
        ),
      );

  test('Done clears a one-off reminder and marks it for sync', () async {
    await addNote('once', 'none');
    expect(await completeReminder(db, 'once'), isTrue);
    final row = await (db.select(
      db.notes,
    )..where((t) => t.id.equals('once'))).getSingle();
    expect(row.reminderAt, isNull);
    expect(row.isReminderSynced, isFalse);
  });

  test('Done leaves a repeating reminder in place', () async {
    await addNote('daily', 'daily');
    expect(await completeReminder(db, 'daily'), isFalse);
    final row = await (db.select(
      db.notes,
    )..where((t) => t.id.equals('daily'))).getSingle();
    expect(row.reminderAt, '2030-01-01T09:00');
  });
}
