import 'package:drift/drift.dart';

@DataClassName('TagRow')
class Tags extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get color => text().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  // The server version this tag was written against; null until it exists there.
  IntColumn get version => integer().nullable()();
  // Must go up on every local edit.
  IntColumn get localRev => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

class NoteTags extends Table {
  TextColumn get noteId => text()();
  TextColumn get tagId => text()();

  @override
  Set<Column> get primaryKey => {noteId, tagId};
}
