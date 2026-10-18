import 'package:anchor/features/notes/presentation/note_folder.dart';
import 'package:anchor/features/notes/presentation/widgets/list_title.dart';
import 'package:anchor/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

final _english = lookupAppLocalizations(const Locale('en'));

void main() {
  String? line(
    NoteFolder folder, {
    bool isOnline = true,
    int unsynced = 0,
    bool hasSyncFailed = false,
  }) => listTitleLine(
    _english,
    folder: folder,
    isOnline: isOnline,
    unsynced: unsynced,
    hasSyncFailed: hasSyncFailed,
  );

  test('the line under the list title shows only when there is news', () {
    expect(line(NoteFolder.notes), isNull);
    expect(line(NoteFolder.archive), 'Hidden from Notes');
    expect(line(NoteFolder.trash), 'Deleted after 30 days');
    expect(
      line(NoteFolder.notes, isOnline: false, unsynced: 2),
      'Offline · 2 changes to sync',
    );
    expect(
      line(NoteFolder.notes, isOnline: false),
      'Offline · changes are saved on this phone',
    );
    expect(line(NoteFolder.notes, hasSyncFailed: true), 'Couldn’t sync');
    expect(
      line(NoteFolder.trash, isOnline: false, unsynced: 1),
      'Offline · 1 change to sync',
      reason: 'sync trouble shows on every list, ahead of what it does',
    );
    expect(line(NoteFolder.archive, hasSyncFailed: true), 'Couldn’t sync');
  });
}
