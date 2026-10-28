import 'package:drift/drift.dart';

/// The stored lock of a note whose lock isn't known yet; see [Notes.lock].
const unknownNoteLock = '';

class Notes extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get content => text().nullable()();
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  TextColumn get background => text().nullable()();
  // State: 'active', 'trashed', 'deleted'
  TextColumn get state => text().withDefault(const Constant('active'))();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().nullable()();
  // Where this person dragged the note on the web; kept and sent back with
  // the note so it isn't lost.
  RealColumn get position => real().nullable()();
  // When it was dragged there; an edit after that sorts by the edit again.
  DateTimeColumn get positionedAt => dateTime().nullable()();
  // What this person locked the note with ('biometric', 'pin', 'pattern',
  // 'tap'), or null. Personal like a pin, and goes up with the note. ''
  // means not known yet (a database from before locks, until the feed
  // brings the note again): nothing is sent for it.
  TextColumn get lock => text().nullable()();
  // Frozen by its owner: nobody can change, trash or delete it until it's
  // unfrozen. The server's say, like sharing: it is never sent up.
  BoolColumn get isFrozen => boolean().withDefault(const Constant(false))();
  // Made invisible by this person: left out of the lists, found by search.
  // Personal like a lock, and goes up with the note. Null means not known
  // yet (a database from before it, until the feed brings the note again):
  // nothing is sent for it.
  BoolColumn get isInvisible => boolean().nullable()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  // The server version this note was written against; null until it exists there.
  IntColumn get version => integer().nullable()();
  // Counts up on every local edit, so an upload can tell if it was overtaken.
  IntColumn get localRev => integer().withDefault(const Constant(0))();
  // A pin belongs to the person, not the note, so it syncs on its own.
  BoolColumn get isPinSynced => boolean().withDefault(const Constant(true))();

  // The note as the server last confirmed it; null until confirmed.
  TextColumn get syncedTitle => text().nullable()();
  TextColumn get syncedContent => text().nullable()();
  TextColumn get syncedBackground => text().nullable()();
  TextColumn get syncedState => text().nullable()();

  // A local wall clock ("YYYY-MM-DDTHH:mm"), not an instant.
  TextColumn get reminderAt => text().nullable()();
  TextColumn get reminderRecurrence => text().nullable()();
  IntColumn get reminderVersion => integer().nullable()();
  BoolColumn get isReminderSynced =>
      boolean().withDefault(const Constant(true))();

  // Local only, never synced: the OS notification id this note occupies.
  IntColumn get reminderSlot => integer().nullable()();

  // Sharing fields
  TextColumn get permission => text().withDefault(const Constant('owner'))();
  TextColumn get shareIds => text().nullable()(); // JSON array of user IDs
  TextColumn get sharedById => text().nullable()();
  TextColumn get sharedByName => text().nullable()();
  TextColumn get sharedByEmail => text().nullable()();
  TextColumn get sharedByProfileImage => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
