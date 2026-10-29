import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import 'note_actions.dart';

enum NoteFolder {
  notes,
  archive,
  trash;

  String titleIn(AppLocalizations l10n) => switch (this) {
    NoteFolder.notes => l10n.navNotes,
    NoteFolder.archive => l10n.navArchive,
    NoteFolder.trash => l10n.navTrash,
  };

  String searchHintIn(AppLocalizations l10n) => switch (this) {
    NoteFolder.notes => l10n.searchNotes,
    NoteFolder.archive => l10n.searchArchive,
    NoteFolder.trash => l10n.searchTrash,
  };

  List<NoteAction> get selectionActions => switch (this) {
    NoteFolder.notes => const [
      NoteAction.tag,
      NoteAction.pin,
      NoteAction.archive,
      NoteAction.trash,
    ],
    NoteFolder.archive => const [NoteAction.unarchive, NoteAction.trash],
    NoteFolder.trash => const [NoteAction.restore, NoteAction.deleteForever],
  };
}

class NoteFolderNotifier extends Notifier<NoteFolder> {
  @override
  NoteFolder build() => NoteFolder.notes;

  void go(NoteFolder folder) => state = folder;
}

final noteFolderProvider = NotifierProvider<NoteFolderNotifier, NoteFolder>(
  NoteFolderNotifier.new,
);
