import 'package:anchor/core/widgets/destruction/destruction.dart';
import 'package:anchor/features/notes/presentation/widgets/note_background_picker.dart';
import 'package:anchor/features/notes/data/repository/notes_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:anchor/features/notes/domain/note.dart';
import 'package:anchor/features/notes/domain/note_filters.dart';
import 'package:anchor/features/notes/domain/note_merge.dart';
import 'package:anchor/core/widgets/confirm_dialog.dart';
import 'package:anchor/features/note_locks/presentation/note_lock_actions.dart';
import 'package:anchor/features/note_locks/presentation/note_lock_session.dart';
import 'package:anchor/features/notes/presentation/note_freeze_actions.dart';
import 'package:anchor/features/notes/presentation/note_invisible_actions.dart';
import '../note_search.dart';
import 'package:anchor/core/widgets/app_snackbar.dart';
import 'package:anchor/features/tags/presentation/tags_controller.dart';
import 'package:anchor/features/tags/presentation/widgets/tag_selector.dart';
import '../notes_controller.dart';
import 'package:anchor/core/widgets/app_bottom_sheet.dart';

class SelectionAppBarActions extends ConsumerWidget {
  final Set<String> selectedNoteIds;
  final VoidCallback onExitSelectionMode;

  const SelectionAppBarActions({
    super.key,
    required this.selectedNoteIds,
    required this.onExitSelectionMode,
  });

  /// Archives the notes, or brings them back when they all are archived.
  Future<void> _handleArchive(
    BuildContext context,
    WidgetRef ref,
    List<String> ids, {
    bool unarchive = false,
  }) async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => ConfirmDialog(
        icon: unarchive ? LucideIcons.archiveRestore : LucideIcons.archive,
        iconColor: theme.colorScheme.primary,
        title: '${unarchive ? 'Unarchive' : 'Archive'} ${_notes(ids.length)}?',
        message: unarchive
            ? '${_these(ids.length)} will be moved back to your notes.'
            : '${_these(ids.length)} will be moved to archive.',
        cancelText: 'Cancel',
        confirmText: unarchive ? 'Unarchive' : 'Archive',
        onConfirm: () {},
      ),
    );
    if (confirmed == true && context.mounted) {
      try {
        final controller = ref.read(notesControllerProvider.notifier);
        if (unarchive) {
          await controller.bulkUnarchiveNotes(ids);
        } else {
          await controller.bulkArchiveNotes(ids);
        }
        onExitSelectionMode();
        if (context.mounted) {
          AppSnackbar.showSuccess(
            context,
            message:
                '${_notes(ids.length)} ${unarchive ? 'unarchived' : 'archived'}',
          );
        }
      } catch (e) {
        if (context.mounted) {
          AppSnackbar.showError(
            context,
            message: unarchive
                ? 'Failed to unarchive notes'
                : 'Failed to archive notes',
          );
        }
      }
    }
  }

  Future<void> _handleDelete(
    BuildContext context,
    WidgetRef ref,
    List<String> ids,
    Set<String> sharedIds,
    Set<String> frozenIds,
  ) async {
    // Frozen notes stay where they are.
    ids = [
      for (final id in ids)
        if (!frozenIds.contains(id)) id,
    ];
    if (ids.isEmpty) {
      AppSnackbar.showInfo(
        context,
        message: 'Frozen notes can’t be deleted. Unfreeze them first.',
      );
      return;
    }
    final sharedCount = sharedIds.length;
    // Your own notes go to trash at once, with Undo. Shared ones ask first:
    // Undo can't bring them back, their owners have to share them again.
    if (sharedCount > 0) {
      final theme = Theme.of(context);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => ConfirmDialog(
          icon: LucideIcons.trash2,
          iconColor: theme.colorScheme.error,
          title: 'Delete ${_notes(ids.length)}?',
          message: _deleteMessage(ids.length, sharedCount),
          cancelText: 'Cancel',
          confirmText: 'Delete',
          onConfirm: () {},
        ),
      );
      if (confirmed != true || !context.mounted) return;
    }
    final repo = ref.read(notesRepositoryProvider);
    final owned = [
      for (final id in ids)
        if (!sharedIds.contains(id)) id,
    ];
    try {
      // The cards burn away in place, then go.
      await burnNoteCards(ids);
      await ref.read(notesControllerProvider.notifier).bulkDeleteNotes(ids);
      onExitSelectionMode();
      if (context.mounted) {
        AppSnackbar.showSuccess(
          context,
          message: _deletedMessage(ids.length, sharedCount),
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

  /// Merges the selected notes into the first: its text gets theirs, its
  /// tags theirs, and they go to the trash. Undo puts all of it back.
  Future<void> _handleMerge(
    BuildContext context,
    WidgetRef ref,
    List<Note> selected,
  ) async {
    if (selected.length < 2) return;
    final unlocked = ref.read(noteLockSessionProvider);
    final String? refusal;
    if (selected.any((n) => !n.isOwner)) {
      refusal = 'Only your own notes can be merged';
    } else if (selected.any((n) => n.isFrozen)) {
      refusal = 'Frozen notes can’t be merged; unfreeze them first';
    } else if (selected.any((n) => isNoteHidden(n, unlocked))) {
      refusal = 'Open the locked notes first, then merge them';
    } else {
      refusal = null;
    }
    if (refusal != null) {
      AppSnackbar.showError(context, message: refusal);
      return;
    }
    final repo = ref.read(notesRepositoryProvider);
    final target = selected.first;
    final others = [for (final note in selected.skip(1)) note.id];
    final keptPictures = selected
        .skip(1)
        .any((n) => n.imagePreviewData.isNotEmpty);
    try {
      await repo.updateNote(mergeNotes(selected));
      await ref.read(notesControllerProvider.notifier).bulkDeleteNotes(others);
      onExitSelectionMode();
      if (context.mounted) {
        AppSnackbar.showSuccess(
          context,
          message: keptPictures
              ? 'Merged ${_notes(selected.length)}; pictures stay with '
                    'their notes in the trash'
              : 'Merged ${_notes(selected.length)}',
          icon: LucideIcons.merge,
          onUndo: () async {
            await repo.updateNote(target);
            for (final id in others) {
              await repo.restoreNote(id);
            }
          },
        );
      }
    } catch (e) {
      if (context.mounted) {
        AppSnackbar.showError(context, message: 'Failed to merge the notes');
      }
    }
  }

  String _notes(int count) => '$count ${count == 1 ? 'note' : 'notes'}';

  String _these(int count) => count == 1 ? 'This note' : 'These notes';

  String _deleteMessage(int count, int sharedCount) {
    if (sharedCount == 0) return '${_these(count)} will be moved to trash.';
    if (sharedCount == count) {
      return '${_these(count)} will be removed from your notes.';
    }
    return 'Notes you own will be moved to trash. '
        'Shared notes will be removed from your notes.';
  }

  String _deletedMessage(int count, int sharedCount) {
    if (sharedCount == 0) return '${_notes(count)} moved to trash';
    if (sharedCount == count) return '${_notes(count)} removed';
    return '${_notes(count)} deleted';
  }

  Future<void> _handlePin(
    BuildContext context,
    WidgetRef ref,
    List<String> ids,
    bool isPinned,
  ) async {
    try {
      await ref
          .read(notesControllerProvider.notifier)
          .bulkSetPinned(ids, isPinned);
      onExitSelectionMode();
      if (context.mounted) {
        AppSnackbar.showSuccess(
          context,
          message: '${_notes(ids.length)} ${isPinned ? 'pinned' : 'unpinned'}',
        );
      }
    } catch (e) {
      if (context.mounted) {
        AppSnackbar.showError(context, message: 'Failed to update pins');
      }
    }
  }

  /// One colour or pattern for every selected note, applied once the sheet
  /// closes.
  Future<void> _handleBackground(
    BuildContext context,
    WidgetRef ref,
    List<Note> selected,
  ) async {
    final current = selected.map((n) => n.background).toSet();
    var chosen = current.length == 1 ? current.first : null;
    var changed = false;
    await AppBottomSheet.show(
      context,
      builder: (context) => NoteBackgroundPicker(
        selectedColor: chosen,
        onColorChanged: (background) {
          chosen = background;
          changed = true;
        },
      ),
    );
    if (!changed || !context.mounted) return;

    try {
      final count = await ref
          .read(notesControllerProvider.notifier)
          .bulkSetBackground(selected.map((n) => n.id).toList(), chosen);
      onExitSelectionMode();
      if (context.mounted) {
        final skipped = selected.length - count;
        AppSnackbar.showSuccess(
          context,
          message: skipped == 0
              ? 'Changed the colour of ${_notes(count)}'
              : 'Changed ${_notes(count)}; '
                    '${_notes(skipped)} shared with you can’t be changed',
        );
      }
    } catch (e) {
      if (context.mounted) {
        AppSnackbar.showError(context, message: 'Failed to change the colour');
      }
    }
  }

  Future<void> _handleTags(
    BuildContext context,
    WidgetRef ref,
    List<String> ids,
  ) async {
    // TagPickerSheet reports the running selection; capture the latest set
    // and merge it into the notes once the sheet is dismissed.
    final selectedTagIds = <String>[];
    await AppBottomSheet.show(
      context,
      builder: (context) => TagPickerSheet(
        selectedTagIds: const [],
        onTagsChanged: (tagIds) {
          selectedTagIds
            ..clear()
            ..addAll(tagIds);
        },
      ),
    );

    if (selectedTagIds.isEmpty || !context.mounted) return;

    try {
      await ref
          .read(notesControllerProvider.notifier)
          .bulkAddTags(ids, selectedTagIds);
      onExitSelectionMode();
      if (context.mounted) {
        AppSnackbar.showSuccess(
          context,
          message: 'Tagged ${_notes(ids.length)}',
        );
      }
    } catch (e) {
      if (context.mounted) {
        AppSnackbar.showError(context, message: 'Failed to add tags');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(notesControllerProvider);
    final query = ref.watch(searchQueryProvider);
    final unlocked = ref.watch(noteLockSessionProvider);
    final theme = Theme.of(context);
    final filters = ref.watch(noteFiltersControllerProvider);
    final searching = query.trim().isNotEmpty || !filters.isEmpty;

    final filteredNotes = notes.maybeWhen(
      data: (notesList) {
        return notesList
            .where(
              (note) =>
                  showsInList(note, searching: searching) &&
                  noteMatchesSearch(
                    note,
                    query,
                    options: ref.watch(searchOptionsProvider),
                    titleOnly: isNoteHidden(note, unlocked),
                  ),
            )
            .toList();
      },
      orElse: () => <Note>[],
    );

    // Archived notes the list shows after the others (a search, a tag or a
    // filter) can be picked too, as in the list.
    final selectedTagId = ref.watch(selectedTagFilterProvider);
    final withArchived =
        query.trim().isNotEmpty || selectedTagId != null || !filters.isEmpty;
    final archivedNotes = !withArchived
        ? const <Note>[]
        : (ref.watch(archiveControllerProvider).value ?? const <Note>[])
              .where(
                (note) =>
                    (selectedTagId == null ||
                        note.tagIds.contains(selectedTagId)) &&
                    showsInList(note, searching: searching) &&
                    filters.matches(note) &&
                    noteMatchesSearch(
                      note,
                      query,
                      titleOnly: isNoteHidden(note, unlocked),
                    ),
              )
              .toList();
    final selectableNotes = [...filteredNotes, ...archivedNotes];

    final allSelected =
        selectableNotes.isNotEmpty &&
        selectedNoteIds.length == selectableNotes.length;

    // When every selected note is already pinned, the toggle unpins instead.
    final selectedNotes = selectableNotes
        .where((note) => selectedNoteIds.contains(note.id))
        .toList();
    final allSelectedPinned =
        selectedNotes.isNotEmpty && selectedNotes.every((n) => n.isPinned);
    // This person's own: they can freeze them, and frozen ones don't delete.
    final ownSelected = selectedNotes.where((n) => n.isOwner).toList();
    final allOwnFrozen =
        ownSelected.isNotEmpty && ownSelected.every((n) => n.isFrozen);
    final allInvisible =
        selectedNotes.isNotEmpty && selectedNotes.every((n) => n.isInvisible);
    final selectedFrozenIds = {
      for (final n in ownSelected)
        if (n.isFrozen) n.id,
    };
    // When every selected note is archived, the toggle unarchives instead.
    final allSelectedArchived =
        selectedNotes.isNotEmpty && selectedNotes.every((n) => n.isArchived);
    final selectedSharedIds = {
      for (final n in [...?notes.value, ...archivedNotes])
        if (selectedNoteIds.contains(n.id) && !n.isOwner) n.id,
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Add tags button
        if (selectedNoteIds.isNotEmpty)
          IconButton(
            icon: const Icon(LucideIcons.tag),
            onPressed: () =>
                _handleTags(context, ref, selectedNoteIds.toList()),
            tooltip: 'Add tags',
          ),
        // Colour
        if (selectedNoteIds.isNotEmpty)
          IconButton(
            icon: const Icon(LucideIcons.palette),
            onPressed: () => _handleBackground(context, ref, selectedNotes),
            tooltip: 'Colour',
          ),
        // Pin / unpin toggle
        if (selectedNoteIds.isNotEmpty)
          IconButton(
            icon: Icon(
              allSelectedPinned ? LucideIcons.pinOff : LucideIcons.pin,
            ),
            onPressed: () => _handlePin(
              context,
              ref,
              selectedNoteIds.toList(),
              !allSelectedPinned,
            ),
            tooltip: allSelectedPinned ? 'Unpin' : 'Pin',
          ),
        // Lock (one choice for them all), freeze / unfreeze the ones this
        // person owns, make them invisible or visible, and merge, under More
        if (selectedNoteIds.isNotEmpty)
          PopupMenuButton<_MoreAction>(
            icon: const Icon(LucideIcons.ellipsisVertical),
            tooltip: 'More',
            onSelected: (action) async {
              switch (action) {
                case _MoreAction.lock:
                  if (await lockSelectedNotes(context, ref, selectedNotes)) {
                    onExitSelectionMode();
                  }
                case _MoreAction.freeze:
                  final done = await setNotesFrozen(context, ref, [
                    for (final n in ownSelected)
                      if (n.isFrozen == allOwnFrozen) n.id,
                  ], !allOwnFrozen);
                  if (done) onExitSelectionMode();
                case _MoreAction.invisible:
                  await setNotesInvisible(context, ref, [
                    for (final n in selectedNotes)
                      if (n.isInvisible == allInvisible) n.id,
                  ], !allInvisible);
                  onExitSelectionMode();
                case _MoreAction.merge:
                  // In the order they were picked: the first one stays.
                  final byId = {for (final n in selectedNotes) n.id: n};
                  await _handleMerge(context, ref, [
                    for (final id in selectedNoteIds) ?byId[id],
                  ]);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: _MoreAction.lock,
                child: ListTile(
                  leading: Icon(LucideIcons.lock),
                  title: Text('Lock…'),
                ),
              ),
              if (ownSelected.isNotEmpty)
                PopupMenuItem(
                  value: _MoreAction.freeze,
                  child: ListTile(
                    leading: const Icon(LucideIcons.snowflake),
                    title: Text(allOwnFrozen ? 'Unfreeze' : 'Freeze'),
                  ),
                ),
              PopupMenuItem(
                value: _MoreAction.invisible,
                child: ListTile(
                  leading: Icon(
                    allInvisible ? LucideIcons.eye : LucideIcons.eyeOff,
                  ),
                  title: Text(allInvisible ? 'Make visible' : 'Make invisible'),
                ),
              ),
              PopupMenuItem(
                value: _MoreAction.merge,
                enabled: selectedNotes.length >= 2,
                child: const ListTile(
                  leading: Icon(LucideIcons.merge),
                  title: Text('Merge notes'),
                ),
              ),
            ],
          ),
        // Archive / unarchive toggle
        if (selectedNoteIds.isNotEmpty)
          IconButton(
            icon: Icon(
              allSelectedArchived
                  ? LucideIcons.archiveRestore
                  : LucideIcons.archive,
            ),
            onPressed: () => _handleArchive(
              context,
              ref,
              selectedNoteIds.toList(),
              unarchive: allSelectedArchived,
            ),
            tooltip: allSelectedArchived ? 'Unarchive' : 'Archive',
          ),
        // Delete button
        if (selectedNoteIds.isNotEmpty)
          IconButton(
            icon: const Icon(LucideIcons.trash2),
            onPressed: () => _handleDelete(
              context,
              ref,
              selectedNoteIds.toList(),
              selectedSharedIds,
              selectedFrozenIds,
            ),
            tooltip: 'Delete',
            color: theme.colorScheme.error,
          ),
        // Select all button
        IconButton(
          icon: Icon(
            allSelected ? LucideIcons.checkSquare : LucideIcons.square,
          ),
          onPressed: () {
            if (allSelected) {
              ref.read(selectedNoteIdsProvider.notifier).clear();
            } else {
              ref
                  .read(selectedNoteIdsProvider.notifier)
                  .selectAll(selectableNotes.map((n) => n.id).toList());
            }
          },
          tooltip: allSelected ? 'Deselect all' : 'Select all',
        ),
      ],
    );
  }
}

enum _MoreAction { lock, freeze, invisible, merge }
