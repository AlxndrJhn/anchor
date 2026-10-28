import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/logging/log_tags.dart';
import '../../../core/network/sync_requester.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../l10n/l10n.dart';
import '../data/repository/note_freeze_repository.dart';
import '../data/repository/notes_repository.dart';
import '../domain/note.dart';

/// Freezes the notes (or unfreezes them) on the server: until they're
/// unfrozen nobody can change, trash or delete them. Only their owner can,
/// and it needs a connection. Edits waiting here go up first. Says so with
/// Undo; returns whether it worked.
Future<bool> setNotesFrozen(
  BuildContext context,
  WidgetRef ref,
  List<String> ids, {
  required bool isFrozen,
  bool offerUndo = true,
}) async {
  if (ids.isEmpty) return false;
  final l10n = context.l10n;
  final server = ref.read(noteFreezeRepositoryProvider);
  final notes = ref.read(notesRepositoryProvider);
  try {
    await requestAppSync(trigger: 'Notes.freeze');
    await server.setFrozen(ids, isFrozen: isFrozen);
    await notes.markFrozen(ids, isFrozen: isFrozen);
    // Brings the notes at their new versions.
    await requestAppSync(trigger: 'Notes.frozen');
  } catch (e) {
    AppLogger.instance.warn(LogTags.notes, 'Freeze failed: $e');
    if (context.mounted) {
      AppSnackbar.show(
        context,
        isFrozen ? l10n.noteFreezeFailed : l10n.noteUnfreezeFailed,
        kind: SnackbarKind.error,
      );
    }
    return false;
  }
  if (context.mounted) {
    AppSnackbar.show(
      context,
      isFrozen ? l10n.notesFrozen(ids.length) : l10n.notesUnfrozen(ids.length),
      kind: SnackbarKind.success,
      actionLabel: offerUndo ? l10n.commonUndo : null,
      onAction: offerUndo
          ? () {
              if (!context.mounted) return;
              setNotesFrozen(
                context,
                ref,
                ids,
                isFrozen: !isFrozen,
                offerUndo: false,
              );
            }
          : null,
    );
  }
  return true;
}

/// Freeze for a selection: the ones this person owns, all frozen when some
/// aren't, else all unfrozen.
List<String> freezableIdsOf(List<Note> notes, {required bool isFreezing}) => [
  for (final note in notes)
    if (note.isOwner && note.isActive && note.isFrozen != isFreezing) note.id,
];

/// Whether Freeze for [notes] unfreezes: every one this person owns is
/// frozen.
bool unfreezesAll(List<Note> notes) {
  final own = notes.where((n) => n.isOwner).toList();
  return own.isNotEmpty && own.every((n) => n.isFrozen);
}
