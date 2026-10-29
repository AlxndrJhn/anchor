import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/widgets/anchor_dialog.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/choice_sheet.dart';
import '../../../l10n/l10n.dart';
import '../../tags/presentation/widgets/tag_sheets.dart';
import '../data/repository/notes_repository.dart';
import '../domain/note.dart';
import '../domain/note_dates.dart';
import 'notes_controller.dart';

enum NoteAction {
  tag,
  pin,
  share,
  history,
  uncheckAll,
  deleteChecked,
  archive,
  unarchive,
  trash,
  restore,
  deleteForever;

  bool get isDanger =>
      this == deleteChecked || this == trash || this == deleteForever;

  ({IconData icon, String label}) iconAndLabelFor(
    List<Note> notes,
    AppLocalizations l10n,
  ) => switch (this) {
    NoteAction.tag => (icon: LucideIcons.tag, label: l10n.actionTag),
    NoteAction.pin when notes.isNotEmpty && notes.every((n) => n.isPinned) => (
      icon: LucideIcons.pinOff,
      label: l10n.actionUnpin,
    ),
    NoteAction.pin => (icon: LucideIcons.pin, label: l10n.actionPin),
    NoteAction.share => (icon: LucideIcons.userPlus, label: l10n.actionShare),
    NoteAction.history => (
      icon: LucideIcons.history,
      label: l10n.actionHistory,
    ),
    NoteAction.uncheckAll => (
      icon: LucideIcons.listRestart,
      label: l10n.actionUncheckAll,
    ),
    NoteAction.deleteChecked => (
      icon: LucideIcons.listX,
      label: l10n.actionDeleteChecked,
    ),
    NoteAction.archive
        when notes.isNotEmpty && notes.every((n) => n.isArchived) =>
      (icon: LucideIcons.archiveRestore, label: l10n.actionUnarchive),
    NoteAction.archive => (
      icon: LucideIcons.archive,
      label: l10n.actionArchive,
    ),
    NoteAction.unarchive => (
      icon: LucideIcons.archiveRestore,
      label: l10n.actionUnarchive,
    ),
    NoteAction.trash => (icon: LucideIcons.trash2, label: l10n.actionDelete),
    NoteAction.restore => (
      icon: LucideIcons.rotateCcw,
      label: l10n.actionRestore,
    ),
    NoteAction.deleteForever => (
      icon: LucideIcons.trash2,
      label: l10n.actionDeletePermanently,
    ),
  };
}

/// [beforeChange] runs once the person has said yes, just before the notes
/// change; [afterChange] runs once they have, before the snackbar shows.
class NoteActions {
  const NoteActions(this.context, this.ref);

  final BuildContext context;
  final WidgetRef ref;

  NotesRepository get _repo => ref.read(notesRepositoryProvider);

  /// Share, history and the checklist actions do nothing here; an open note
  /// handles them itself.
  Future<void> run(
    NoteAction action,
    List<Note> notes, {
    FutureOr<void> Function()? beforeChange,
  }) async {
    switch (action) {
      case NoteAction.tag:
        await showTagPicker(context, notes);
      case NoteAction.pin:
        await beforeChange?.call();
        await pin(notes);
      case NoteAction.archive:
        await archive(notes, beforeChange: beforeChange);
      case NoteAction.unarchive:
        await beforeChange?.call();
        await unarchive(notes);
      case NoteAction.trash:
        await trash(notes, beforeChange: beforeChange);
      case NoteAction.restore:
        await beforeChange?.call();
        await restore(notes);
      case NoteAction.deleteForever:
        await deleteForever(notes, beforeChange: beforeChange);
      case NoteAction.share ||
          NoteAction.history ||
          NoteAction.uncheckAll ||
          NoteAction.deleteChecked:
        break;
    }
  }

  Future<void> pin(List<Note> notes) async {
    if (notes.isEmpty) return;
    final repo = _repo;
    final l10n = context.l10n;
    final isPinning = !notes.every((n) => n.isPinned);
    final wasPinned = [
      for (final n in notes)
        if (n.isPinned) n.id,
    ];
    final wasUnpinned = [
      for (final n in notes)
        if (!n.isPinned) n.id,
    ];
    await repo.setPinned(_idsOf(notes), isPinning);
    if (!context.mounted) return;
    AppSnackbar.show(
      context,
      isPinning
          ? l10n.notesPinned(notes.length)
          : l10n.notesUnpinned(notes.length),
      actionLabel: l10n.commonUndo,
      onAction: () async {
        await repo.setPinned(wasPinned, true);
        await repo.setPinned(wasUnpinned, false);
      },
    );
  }

  /// Unarchives when every note is archived already.
  Future<void> archive(
    List<Note> notes, {
    FutureOr<void> Function()? beforeChange,
    VoidCallback? afterChange,
  }) async {
    if (notes.isEmpty) return;
    if (notes.every((n) => n.isArchived)) {
      await beforeChange?.call();
      return unarchive(notes);
    }
    final l10n = context.l10n;
    final repo = _repo;
    final ids = [
      for (final n in notes)
        if (!n.isArchived) n.id,
    ];
    await beforeChange?.call();
    await repo.archive(ids);
    if (!context.mounted) return;
    afterChange?.call();
    AppSnackbar.show(
      context,
      l10n.notesArchived(ids.length),
      actionLabel: l10n.commonUndo,
      onAction: () => repo.unarchive(ids),
    );
  }

  Future<void> unarchive(List<Note> notes) async {
    if (notes.isEmpty) return;
    final l10n = context.l10n;
    final repo = _repo;
    final ids = _idsOf(notes);
    await repo.unarchive(ids);
    if (!context.mounted) return;
    AppSnackbar.show(
      context,
      l10n.notesUnarchived(ids.length),
      actionLabel: l10n.commonUndo,
      onAction: () => repo.archive(ids),
    );
  }

  /// Trashes the person's own notes and leaves notes shared with them.
  Future<void> trash(
    List<Note> notes, {
    FutureOr<void> Function()? beforeChange,
    VoidCallback? afterChange,
  }) async {
    if (notes.isEmpty) return;
    final l10n = context.l10n;
    final repo = _repo;
    final shared = notes.where((n) => !n.isOwner).toList();
    final own = notes.where((n) => n.isOwner).toList();
    if (shared.isNotEmpty) {
      final isOneShared = shared.length == 1;
      final isOnlyShared = own.isEmpty;
      final ok = await showAnchorDialog(
        context,
        title: isOneShared && isOnlyShared
            ? l10n.notesRemoveSharedTitle
            : l10n.notesDeleteTitle(notes.length),
        message: isOneShared && isOnlyShared
            ? l10n.notesRemoveSharedMessage
            : l10n.notesDeleteSharedMessage(shared.length),
        confirmLabel: isOnlyShared ? l10n.actionRemove : l10n.actionDelete,
        icon: LucideIcons.logOut,
        isDanger: true,
      );
      if (!ok || !context.mounted) return;
    }
    await beforeChange?.call();
    await repo.trash(_idsOf(notes));
    if (!context.mounted) return;
    afterChange?.call();
    final ownIds = _idsOf(own);
    AppSnackbar.show(
      context,
      _trashedMessage(own: own.length, shared: shared.length, l10n: l10n),
      actionLabel: ownIds.isEmpty ? null : l10n.commonUndo,
      onAction: ownIds.isEmpty ? null : () => repo.restore(ownIds),
    );
  }

  Future<void> restore(List<Note> notes) async {
    if (notes.isEmpty) return;
    final l10n = context.l10n;
    final repo = _repo;
    final ids = _idsOf(notes);
    await repo.restore(ids);
    if (!context.mounted) return;
    AppSnackbar.show(
      context,
      l10n.notesRestored(ids.length),
      actionLabel: l10n.commonUndo,
      onAction: () => repo.trash(ids),
    );
  }

  Future<void> deleteForever(
    List<Note> notes, {
    FutureOr<void> Function()? beforeChange,
    VoidCallback? afterChange,
  }) async {
    if (notes.isEmpty) return;
    final l10n = context.l10n;
    final repo = _repo;
    final isOne = notes.length == 1;
    final ok = await showAnchorDialog(
      context,
      title: isOne
          ? l10n.notesDeleteForeverOneTitle
          : l10n.notesDeleteForeverTitle(notes.length),
      message: l10n.notesDeleteForeverMessage(notes.length),
      confirmLabel: l10n.actionDeletePermanently,
      icon: LucideIcons.trash2,
      isDanger: true,
    );
    if (!ok || !context.mounted) return;
    await beforeChange?.call();
    await repo.deleteForever(_idsOf(notes));
    if (!context.mounted) return;
    afterChange?.call();
    AppSnackbar.show(context, l10n.notesDeletedForever(notes.length));
  }

  Future<void> emptyTrash() async {
    final l10n = context.l10n;
    final repo = _repo;
    final count = (ref.read(trashedNotesProvider).value ?? const []).length;
    final isEmptying = await showChoiceSheet<bool>(
      context,
      title: l10n.navTrash,
      subtitle: l10n.trashRule(trashDays),
      choices: [
        SheetChoice(
          value: true,
          icon: LucideIcons.trash2,
          label: l10n.trashEmptyAction,
          subtitle: count == 0 ? l10n.trashNothing : l10n.notesCount(count),
          isDanger: true,
          enabled: count > 0,
        ),
      ],
    );
    if (isEmptying != true || !context.mounted) return;
    final ok = await showAnchorDialog(
      context,
      title: l10n.trashEmptyTitle,
      message: l10n.trashEmptyMessage(count),
      confirmLabel: l10n.trashEmptyAction,
      icon: LucideIcons.trash2,
      isDanger: true,
    );
    if (!ok) return;
    await repo.deleteForever(
      _idsOf(ref.read(trashedNotesProvider).value ?? const []),
    );
    if (context.mounted) AppSnackbar.show(context, l10n.trashEmptied);
  }

  static List<String> _idsOf(List<Note> notes) => [for (final n in notes) n.id];

  static String _trashedMessage({
    required int own,
    required int shared,
    required AppLocalizations l10n,
  }) {
    if (own > 0 && shared > 0) {
      return l10n.notesTrashedMixed(
        l10n.notesMovedToTrashPart(own),
        l10n.notesRemovedPart(shared),
      );
    }
    return own > 0
        ? l10n.notesMovedToTrash(own)
        : l10n.notesRemovedFromYours(shared);
  }
}
