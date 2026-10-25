import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:anchor/features/notes/domain/note.dart';
import 'package:anchor/core/widgets/confirm_dialog.dart';
import 'package:anchor/core/widgets/app_snackbar.dart';
import 'package:anchor/features/notes/presentation/widgets/note_list_page.dart';
import 'notes_controller.dart';

class TrashScreen extends ConsumerWidget {
  const TrashScreen({super.key});

  void _showRestoreDialog(BuildContext context, WidgetRef ref, Note note) {
    showDialog(
      context: context,
      builder: (ctx) => ConfirmDialog(
        icon: LucideIcons.rotateCcw,
        iconColor: Theme.of(context).colorScheme.primary,
        title: 'Restore note?',
        message: 'This note will be moved back to your notes.',
        cancelText: 'Cancel',
        confirmText: 'Restore',
        onConfirm: () async {
          try {
            await ref
                .read(trashControllerProvider.notifier)
                .restoreNote(note.id);
            if (context.mounted) {
              AppSnackbar.showSuccess(context, message: 'Note restored');
            }
          } catch (_) {
            if (context.mounted) {
              AppSnackbar.showError(context, message: 'Failed to restore note');
            }
          }
        },
      ),
    );
  }

  void _showPermanentDeleteDialog(
    BuildContext context,
    WidgetRef ref,
    Note note,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => ConfirmDialog(
        icon: LucideIcons.trash2,
        iconColor: Theme.of(context).colorScheme.error,
        title: 'Delete permanently?',
        message: 'This note will be permanently deleted.',
        cancelText: 'Cancel',
        confirmText: 'Delete permanently',
        confirmColor: Theme.of(context).colorScheme.error,
        onConfirm: () async {
          try {
            await ref
                .read(trashControllerProvider.notifier)
                .permanentDelete(note.id);
            if (context.mounted) {
              AppSnackbar.showSuccess(
                context,
                message: 'Note permanently deleted',
              );
            }
          } catch (_) {
            if (context.mounted) {
              AppSnackbar.showError(context, message: 'Failed to delete note');
            }
          }
        },
      ),
    );
  }

  void _showEmptyTrashDialog(BuildContext context, WidgetRef ref, int count) {
    showDialog(
      context: context,
      builder: (ctx) => ConfirmDialog(
        icon: LucideIcons.trash2,
        iconColor: Theme.of(context).colorScheme.error,
        title: 'Empty trash?',
        message:
            '${count == 1 ? 'The note' : 'All $count notes'} in the trash will be permanently deleted.',
        cancelText: 'Cancel',
        confirmText: 'Empty trash',
        confirmColor: Theme.of(context).colorScheme.error,
        onConfirm: () async {
          try {
            final deleted = await ref
                .read(trashControllerProvider.notifier)
                .emptyTrash();
            if (context.mounted) {
              AppSnackbar.showSuccess(
                context,
                message:
                    '${deleted == 1 ? '1 note' : '$deleted notes'} permanently deleted',
              );
            }
          } catch (_) {
            if (context.mounted) {
              AppSnackbar.showError(context, message: 'Failed to empty trash');
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trashed = ref.watch(trashControllerProvider);
    final count = trashed.value?.length ?? 0;
    return NoteListPage(
      title: 'Trash',
      notes: trashed,
      actions: [
        if (count > 0)
          IconButton(
            icon: const Icon(LucideIcons.trash),
            tooltip: 'Empty trash',
            onPressed: () => _showEmptyTrashDialog(context, ref, count),
          ),
      ],
      emptyIcon: LucideIcons.trash2,
      emptyMessage: 'Trash is empty',
      datePrefix: 'Moved to trash',
      trailingActions: (note) => [
        IconButton(
          icon: const Icon(LucideIcons.rotateCcw),
          onPressed: () => _showRestoreDialog(context, ref, note),
          tooltip: 'Restore',
          visualDensity: VisualDensity.compact,
        ),
        IconButton(
          icon: Icon(
            LucideIcons.trash2,
            color: Theme.of(context).colorScheme.error,
          ),
          onPressed: () => _showPermanentDeleteDialog(context, ref, note),
          tooltip: 'Delete permanently',
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}
