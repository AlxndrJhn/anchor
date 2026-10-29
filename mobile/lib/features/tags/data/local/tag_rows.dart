import '../../../../core/database/app_database.dart';

/// None opens a transaction: each runs inside its caller's.
extension TagRows on AppDatabase {
  Future<TagRow?> tagRow(String id) =>
      (select(tags)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();

  Future<void> writeTag(String id, TagsCompanion values) async {
    await (update(tags)..where((tbl) => tbl.id.equals(id))).write(values);
  }
}
