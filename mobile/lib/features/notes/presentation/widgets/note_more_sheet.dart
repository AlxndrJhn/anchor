import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/widgets/choice_sheet.dart';
import '../../../../l10n/l10n.dart';
import '../note_actions.dart';

Future<NoteAction?> showNoteMoreSheet(
  BuildContext context, {
  required bool isPinned,
  required bool isOwner,
  required bool isArchived,
  required bool canSeeHistory,
  required int shareCount,
  bool hasChecklist = false,
  bool hasCheckedItems = false,
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
      null,
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
        null,
      ],
      isArchived
          ? SheetChoice(
              value: NoteAction.unarchive,
              icon: LucideIcons.archiveRestore,
              label: l10n.actionUnarchive,
            )
          : SheetChoice(
              value: NoteAction.archive,
              icon: LucideIcons.archive,
              label: l10n.actionArchive,
            ),
      isOwner
          ? SheetChoice(
              value: NoteAction.trash,
              icon: LucideIcons.trash2,
              label: l10n.actionMoveToTrash,
              isDanger: true,
            )
          : SheetChoice(
              value: NoteAction.trash,
              icon: LucideIcons.logOut,
              label: l10n.actionRemoveFromMine,
              isDanger: true,
            ),
    ],
  );
}
