import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/widgets/choice_sheet.dart';
import '../../../../l10n/l10n.dart';
import '../../../note_locks/presentation/note_lock_actions.dart';
import '../../domain/note.dart';
import '../note_actions.dart';

Future<NoteAction?> showNoteMoreSheet(
  BuildContext context, {
  required bool isPinned,
  required bool isOwner,
  required bool canSeeHistory,
  required int shareCount,
  bool canCopy = true,
  bool canLock = false,
  NoteLock? lock,
  bool hasChecklist = false,
  bool hasCheckedItems = false,
  bool canShowCheckboxes = false,
  bool canHideCheckboxes = false,
}) {
  final l10n = context.l10n;
  return showChoiceSheet<NoteAction>(
    context,
    semanticLabel: l10n.commonMore,
    choices: [
      SheetChoice(
        value: NoteAction.pin,
        icon: isPinned ? LucideIcons.pinOff : LucideIcons.pin,
        label: isPinned ? l10n.actionUnpin : l10n.actionPin,
      ),
      if (isOwner)
        SheetChoice(
          value: NoteAction.share,
          icon: LucideIcons.userPlus,
          label: shareCount > 0 ? l10n.actionSharing : l10n.actionShare,
          detail: shareCount > 0 ? l10n.peopleCount(shareCount) : null,
          showChevron: true,
        ),
      if (canSeeHistory)
        SheetChoice(
          value: NoteAction.history,
          icon: LucideIcons.history,
          label: l10n.actionHistory,
          showChevron: true,
        ),
      SheetChoice(
        value: NoteAction.send,
        icon: LucideIcons.send,
        label: l10n.actionSend,
      ),
      if (canCopy)
        SheetChoice(
          value: NoteAction.copy,
          icon: LucideIcons.copy,
          label: l10n.actionMakeCopy,
        ),
      if (canLock) ...[
        SheetChoice(
          value: NoteAction.lock,
          icon: LucideIcons.lock,
          label: lock == null ? l10n.actionLock : l10n.actionChangeLock,
          detail: lock == null ? null : noteLockLabel(lock, l10n),
          showChevron: true,
        ),
        if (lock != null)
          SheetChoice(
            value: NoteAction.removeLock,
            icon: LucideIcons.lockOpen,
            label: l10n.actionRemoveLock,
          ),
      ],
      null,
      if (canShowCheckboxes)
        SheetChoice(
          value: NoteAction.showCheckboxes,
          icon: LucideIcons.listChecks,
          label: l10n.actionShowCheckboxes,
        )
      else if (canHideCheckboxes)
        SheetChoice(
          value: NoteAction.hideCheckboxes,
          icon: LucideIcons.list,
          label: l10n.actionHideCheckboxes,
        ),
      if (hasChecklist) ...[
        SheetChoice(
          value: NoteAction.uncheckAll,
          icon: LucideIcons.listRestart,
          label: l10n.actionUncheckAll,
          enabled: hasCheckedItems,
        ),
        SheetChoice(
          value: NoteAction.deleteChecked,
          icon: LucideIcons.listX,
          label: l10n.actionDeleteChecked,
          isDanger: true,
          enabled: hasCheckedItems,
        ),
      ],
    ],
  );
}
