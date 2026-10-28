import 'package:anchor/core/logging/app_logger.dart';
import 'package:anchor/core/network/dio_provider.dart';
import 'package:anchor/core/network/sync_requester.dart';
import 'package:anchor/core/widgets/app_snackbar.dart';
import 'package:anchor/features/notes/data/repository/notes_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Freezes the notes (or unfreezes them) on the server: until they're
/// unfrozen nobody can change, trash or delete them. Only their owner can,
/// and it needs a connection, so a phone that's behind never unfreezes a
/// note by mistake. Edits waiting here go up first. Says so with Undo;
/// returns whether it worked.
Future<bool> setNotesFrozen(
  BuildContext context,
  WidgetRef ref,
  List<String> ids,
  bool isFrozen, {
  bool offerUndo = true,
}) async {
  if (ids.isEmpty) return false;
  final dio = ref.read(dioProvider);
  final repo = ref.read(notesRepositoryProvider);
  try {
    await requestAppSync(trigger: 'Notes.freeze');
    if (ids.length == 1) {
      await dio.patch<void>(
        '/api/notes/${ids.single}/freeze',
        data: {'isFrozen': isFrozen},
      );
    } else {
      await dio.post<void>(
        '/api/notes/bulk/freeze',
        data: {'noteIds': ids, 'isFrozen': isFrozen},
      );
    }
    await repo.markFrozen(ids, isFrozen);
    // Brings the notes at their new versions.
    await requestAppSync(trigger: 'Notes.frozen');
  } catch (e) {
    AppLogger.instance.warn('Notes', 'Freeze failed: $e');
    if (context.mounted) {
      AppSnackbar.showError(
        context,
        message:
            'Couldn’t ${isFrozen ? 'freeze' : 'unfreeze'}. '
            'It needs a connection to the server.',
      );
    }
    return false;
  }
  if (context.mounted) {
    final count = ids.length;
    final what = count == 1 ? 'Note' : '$count notes';
    AppSnackbar.showSuccess(
      context,
      message: '$what ${isFrozen ? 'frozen' : 'unfrozen'}',
      onUndo: offerUndo
          ? () => setNotesFrozen(context, ref, ids, !isFrozen, offerUndo: false)
          : null,
    );
  }
  return true;
}
