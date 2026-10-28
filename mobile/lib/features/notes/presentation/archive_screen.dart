import 'package:anchor/core/widgets/destruction/destruction.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:anchor/features/notes/data/repository/notes_repository.dart';
import 'package:anchor/features/notes/domain/note.dart';
import 'package:anchor/core/widgets/confirm_dialog.dart';
import 'package:anchor/core/widgets/app_snackbar.dart';
import 'package:anchor/features/notes/presentation/widgets/note_list_page.dart';
import 'notes_controller.dart';

class ArchiveScreen extends ConsumerWidget {
  const ArchiveScreen({super.key});

  void _showUnarchiveDialog(BuildContext context, WidgetRef ref, Note note) {
    showDialog(
      context: context,
      builder: (ctx) => ConfirmDialog(
        icon: LucideIcons.archiveRestore,
        iconColor: Theme.of(context).colorScheme.primary,
        title: 'Unarchive note?',
        message: 'This note will be moved back to your notes.',
        cancelText: 'Cancel',
        confirmText: 'Unarchive',
        onConfirm: () async {
          try {
            await ref
                .read(archiveControllerProvider.notifier)
                .unarchiveNote(note.id);
            if (context.mounted) {
              AppSnackbar.showSuccess(context, message: 'Note unarchived');
            }
          } catch (e) {
            if (context.mounted) {
              AppSnackbar.showError(
                context,
                message: 'Failed to unarchive note',
              );
            }
          }
        },
      ),
    );
  }

  String _notes(int count) => '$count ${count == 1 ? 'note' : 'notes'}';

  String _these(int count) => count == 1 ? 'This note' : 'These notes';

  Future<void> _unarchiveSelected(
    BuildContext context,
    WidgetRef ref,
    List<Note> notes,
    VoidCallback done,
  ) async {
    final ids = [for (final n in notes) n.id];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => ConfirmDialog(
        icon: LucideIcons.archiveRestore,
        iconColor: Theme.of(context).colorScheme.primary,
        title: 'Unarchive ${_notes(ids.length)}?',
        message: '${_these(ids.length)} will be moved back to your notes.',
        cancelText: 'Cancel',
        confirmText: 'Unarchive',
        onConfirm: () {},
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref
          .read(archiveControllerProvider.notifier)
          .bulkUnarchiveNotes(ids);
      done();
      if (context.mounted) {
        AppSnackbar.showSuccess(
          context,
          message: '${_notes(ids.length)} unarchived',
        );
      }
    } catch (e) {
      if (context.mounted) {
        AppSnackbar.showError(context, message: 'Failed to unarchive notes');
      }
    }
  }

  /// As in the notes list: your own notes go to trash at once, with Undo;
  /// shared ones ask first, as Undo can't bring them back.
  Future<void> _deleteSelected(
    BuildContext context,
    WidgetRef ref,
    List<Note> notes,
    VoidCallback done,
  ) async {
    final ids = [for (final n in notes) n.id];
    final owned = [
      for (final n in notes)
        if (n.isOwner) n.id,
    ];
    final sharedCount = ids.length - owned.length;
    if (sharedCount > 0) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => ConfirmDialog(
          icon: LucideIcons.trash2,
          iconColor: Theme.of(context).colorScheme.error,
          title: 'Delete ${_notes(ids.length)}?',
          message: sharedCount == ids.length
              ? '${_these(ids.length)} will be removed from your notes.'
              : 'Notes you own will be moved to trash. '
                    'Shared notes will be removed from your notes.',
          cancelText: 'Cancel',
          confirmText: 'Delete',
          onConfirm: () {},
        ),
      );
      if (confirmed != true || !context.mounted) return;
    }
    final repo = ref.read(notesRepositoryProvider);
    try {
      // The cards burn away in place, then go.
      await burnNoteCards(ids);
      await ref.read(archiveControllerProvider.notifier).bulkDeleteNotes(ids);
      done();
      if (context.mounted) {
        AppSnackbar.showSuccess(
          context,
          message: sharedCount == 0
              ? '${_notes(ids.length)} moved to trash'
              : sharedCount == ids.length
              ? '${_notes(ids.length)} removed'
              : '${_notes(ids.length)} deleted',
          onUndo: owned.isEmpty
              ? null
              : () async {
                  for (final id in owned) {
                    await repo.restoreNote(id);
                  }
                },
        );
      }
    } catch (e) {
      if (context.mounted) {
        AppSnackbar.showError(context, message: 'Failed to delete notes');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return NoteListPage(
      title: 'Archive',
      notes: ref.watch(archiveControllerProvider),
      emptyIcon: LucideIcons.archive,
      emptyMessage: 'Archive is empty',
      datePrefix: 'Edited',
      trailingActions: (note) => [
        IconButton(
          icon: const Icon(LucideIcons.archiveRestore),
          onPressed: () => _showUnarchiveDialog(context, ref, note),
          tooltip: 'Unarchive',
          visualDensity: VisualDensity.compact,
        ),
      ],
      selectionActions: (selected, done) => [
        IconButton(
          icon: const Icon(LucideIcons.archiveRestore),
          onPressed: () => _unarchiveSelected(context, ref, selected, done),
          tooltip: 'Unarchive',
        ),
        IconButton(
          icon: const Icon(LucideIcons.trash2),
          onPressed: () => _deleteSelected(context, ref, selected, done),
          tooltip: 'Delete',
          color: Theme.of(context).colorScheme.error,
        ),
      ],
    );
  }
}
