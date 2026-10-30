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
  bool canAddPictures = false,
  bool canFreeze = false,
  bool isFrozen = false,
  bool canMakeInvisible = false,
  bool isInvisible = false,
}) {
  final l10n = context.l10n;
  final pin = SheetChoice(
    value: NoteAction.pin,
    icon: isPinned ? LucideIcons.pinOff : LucideIcons.pin,
    label: isPinned ? l10n.actionUnpin : l10n.actionPin,
  );
  return showChoiceSheet<NoteAction>(
    context,
    semanticLabel: l10n.commonMore,
    choices: [
      pin,
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
      if (canFreeze)
        SheetChoice(
          value: NoteAction.freeze,
          icon: LucideIcons.snowflake,
          label: isFrozen ? l10n.actionUnfreeze : l10n.actionFreeze,
          subtitle: isFrozen ? null : l10n.noteFreezeHelp,
        ),
      if (canMakeInvisible)
        SheetChoice(
          value: NoteAction.invisible,
          icon: isInvisible ? LucideIcons.eye : LucideIcons.eyeOff,
          label: isInvisible
              ? l10n.actionMakeVisible
              : l10n.actionMakeInvisible,
          subtitle: isInvisible ? null : l10n.noteInvisibleHelp,
        ),
      if (canAddPictures) ...[
        null,
        for (final action in const [
          NoteAction.addImage,
          NoteAction.takePicture,
          NoteAction.takeSeveral,
        ])
          SheetChoice(
            value: action,
            icon: action.iconAndLabelFor(const [], l10n).icon,
            label: action.iconAndLabelFor(const [], l10n).label,
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
