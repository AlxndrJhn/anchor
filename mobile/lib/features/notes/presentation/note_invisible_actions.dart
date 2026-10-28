import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/motion/haptics.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../l10n/l10n.dart';
import '../data/repository/notes_repository.dart';
import '../domain/note.dart';

/// Makes the notes invisible for this person (left out of the lists, found
/// by search), or shows them again. Their own, like a lock, so it works
/// offline and goes up with the notes. Says so with Undo.
Future<void> setNotesInvisible(
  BuildContext context,
  WidgetRef ref,
  List<String> ids, {
  required bool isInvisible,
  bool offerUndo = true,
}) async {
  if (ids.isEmpty) return;
  final l10n = context.l10n;
  await ref
      .read(notesRepositoryProvider)
      .setInvisible(ids, isInvisible: isInvisible);
  Haptics.success();
  if (!context.mounted) return;
  AppSnackbar.show(
    context,
    isInvisible
        ? l10n.notesMadeInvisible(ids.length)
        : l10n.notesMadeVisible(ids.length),
    kind: SnackbarKind.success,
    actionLabel: offerUndo ? l10n.commonUndo : null,
    onAction: offerUndo
        ? () {
            if (!context.mounted) return;
            setNotesInvisible(
              context,
              ref,
              ids,
              isInvisible: !isInvisible,
              offerUndo: false,
            );
          }
        : null,
  );
}

/// Whether Make invisible for [notes] makes them visible again: every one
/// is invisible.
bool makesVisible(List<Note> notes) =>
    notes.isNotEmpty && notes.every((n) => n.isInvisible);

/// The notes Make invisible (or visible) changes.
List<String> invisibleIdsOf(List<Note> notes, {required bool isInvisible}) => [
  for (final note in notes)
    if (note.isInvisible != isInvisible) note.id,
];
