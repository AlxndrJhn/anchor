import 'package:anchor/core/widgets/app_snackbar.dart';
import 'package:anchor/features/notes/data/repository/notes_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Makes the notes invisible for this person (left out of the lists, found
/// by search), or shows them again. Their own, like a lock, so it works
/// offline and goes up with the notes. Says so with Undo.
Future<void> setNotesInvisible(
  BuildContext context,
  WidgetRef ref,
  List<String> ids,
  bool isInvisible, {
  bool offerUndo = true,
}) async {
  if (ids.isEmpty) return;
  final repo = ref.read(notesRepositoryProvider);
  await repo.setInvisible(ids, isInvisible);
  if (!context.mounted) return;
  final count = ids.length;
  final what = count == 1 ? 'Note' : '$count notes';
  AppSnackbar.showSuccess(
    context,
    message: isInvisible
        ? '$what made invisible. Search finds ${count == 1 ? 'it' : 'them'}.'
        : '$what made visible',
    onUndo: offerUndo
        ? () => setNotesInvisible(
            context,
            ref,
            ids,
            !isInvisible,
            offerUndo: false,
          )
        : null,
  );
}
