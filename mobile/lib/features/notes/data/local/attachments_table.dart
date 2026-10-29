import 'package:drift/drift.dart';

@DataClassName('AttachmentRow')
class NoteAttachments extends Table {
  TextColumn get id => text()();
  TextColumn get noteId => text()();
  // 'image' or 'audio'
  TextColumn get type => text()();
  TextColumn get originalFilename => text()();
  TextColumn get mimeType => text()();
  IntColumn get fileSize => integer()();
  IntColumn get position => integer().withDefault(const Constant(0))();
  // Local file path (null if not cached)
  TextColumn get localPath => text().nullable()();
  // AttachmentSyncStatus.dbValue: 'synced' | 'pending_upload' | 'pending_delete'
  TextColumn get syncStatus => text().withDefault(const Constant('synced'))();
  // Server assigned ID (null before first upload)
  TextColumn get serverAttachmentId => text().nullable()();
  // Null for local uploads not yet sent.
  TextColumn get uploadedByUserId => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
