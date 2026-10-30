import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/context_extensions.dart';
import '../../../../core/theme/tokens/anchor_tokens.dart';
import '../../../../core/widgets/app_buttons.dart';
import '../../../../core/widgets/page_bar.dart';
import '../../../../l10n/l10n.dart';
import '../../../reminders/domain/reminder_times.dart';
import '../../../reminders/presentation/reminder_labels.dart';
import '../../domain/note.dart';
import '../../domain/quick_action.dart';
import '../quick_action_labels.dart';
import 'note_surface.dart';

class NoteBar extends StatelessWidget {
  const NoteBar({
    super.key,
    required this.appearance,
    required this.scrollOffset,
    required this.reminder,
    required this.isUnsynced,
    required this.isTrashed,
    required this.isReadOnly,
    required this.onBack,
    required this.onHistory,
    required this.onBackground,
    required this.onReminder,
    required this.onMore,
    this.isArchived = false,
    this.isOwner = true,
    this.onArchive,
    this.onTrash,
    this.quickActions = QuickAction.defaults,
    this.isPinned = false,
    this.onPin,
    this.onQuickAction,
  });

  final NoteAppearance appearance;
  final ScrollOffset scrollOffset;
  final NoteReminder? reminder;
  final bool isUnsynced;
  final bool isTrashed;
  final bool isReadOnly;
  final VoidCallback onBack;
  final VoidCallback onHistory;
  final VoidCallback onBackground;
  final VoidCallback onReminder;

  /// Null while the note is new and has nothing to act on yet.
  final VoidCallback? onMore;

  /// Archive turns into Unarchive on an archived note.
  final bool isArchived;

  /// Delete moves your own note to the trash; a note shared with you is
  /// taken out of your notes instead.
  final bool isOwner;

  /// Archive or Unarchive; null (no button) while the note is new.
  final VoidCallback? onArchive;

  /// Delete; null (no button) while the note is new.
  final VoidCallback? onTrash;

  /// The buttons beside More, in order; each shows only when it can act.
  final List<QuickAction> quickActions;

  /// Pin turns into Unpin on a pinned note.
  final bool isPinned;
  final VoidCallback? onPin;

  /// The rest of [quickActions]; null leaves them out.
  final ValueChanged<QuickAction>? onQuickAction;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final actions = <Widget>[
      if (isTrashed)
        BarButton(
          icon: LucideIcons.history,
          label: l10n.actionHistory,
          onPressed: onHistory,
        )
      else ...[
        for (final action in quickActions) ?_buttonFor(action, l10n),
        BarButton(
          icon: LucideIcons.ellipsis,
          label: l10n.commonMore,
          onPressed: onMore,
        ),
      ],
    ];
    final leading = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PageBackButton(onPressed: onBack),
        if (isUnsynced)
          _UnsyncedBadge(
            appearance: appearance,
            isCompact: !_badgeFits(context, actions.length),
          ),
      ],
    );
    return PageBar(
      color: appearance.colors.bg,
      scrollOffset: scrollOffset,
      leading: leading,
      actions: actions,
    );
  }

  Widget? _buttonFor(QuickAction action, AppLocalizations l10n) =>
      switch (action) {
        QuickAction.trash => switch (onTrash) {
          final onTrash? => BarButton(
            icon: isOwner ? LucideIcons.trash2 : LucideIcons.logOut,
            label: isOwner ? l10n.actionMoveToTrash : l10n.actionRemoveFromMine,
            onPressed: onTrash,
          ),
          null => null,
        },
        QuickAction.background =>
          isReadOnly
              ? null
              : BarButton(
                  icon: LucideIcons.palette,
                  label: l10n.noteBackground,
                  onPressed: onBackground,
                ),
        QuickAction.pin => switch (onPin) {
          // Toggles in place, marked while pinned, as Archive does.
          final onPin? => BarButton(
            icon: LucideIcons.pin,
            label: isPinned ? l10n.actionUnpin : l10n.actionPin,
            isOn: isPinned,
            onPressed: onPin,
          ),
          null => null,
        },
        QuickAction.reminder => _ReminderButton(
          reminder: reminder,
          onPressed: onReminder,
        ),
        QuickAction.archive => switch (onArchive) {
          // Toggles in place, marked while archived, as a tool is.
          final onArchive? => BarButton(
            icon: LucideIcons.archive,
            label: isArchived ? l10n.actionUnarchive : l10n.actionArchive,
            isOn: isArchived,
            onPressed: onArchive,
          ),
          null => null,
        },
        _ => switch (onQuickAction) {
          final onQuickAction? => BarButton(
            icon: action.iconAndLabel(l10n).icon,
            label: action.iconAndLabel(l10n).label,
            onPressed: () => onQuickAction(action),
          ),
          null => null,
        },
      };

  /// Whether the "On this phone" badge fits beside Back and [actionCount]
  /// buttons; on a narrow phone it shrinks to its icon.
  bool _badgeFits(BuildContext context, int actionCount) {
    final label = TextPainter(
      text: TextSpan(
        text: context.l10n.noteOnThisPhone,
        style: AppTypography.footnote,
      ),
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: Directionality.of(context),
      maxLines: 1,
    )..layout();
    final badge = _UnsyncedBadge.chrome + label.width;
    label.dispose();
    final buttons = (actionCount + 1) * AnchorTokens.sizeControlMedium;
    return 2 * PageBar.inset + buttons + badge <=
        MediaQuery.sizeOf(context).width;
  }
}

class _UnsyncedBadge extends StatelessWidget {
  const _UnsyncedBadge({required this.appearance, this.isCompact = false});

  final NoteAppearance appearance;

  /// Only the icon, when the bar is short of room.
  final bool isCompact;

  /// The badge's width beside its words: margin, padding, icon and gap.
  static const double chrome = 4 + 2 * 8 + AnchorTokens.sizeIconSmall + 4;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.l10n.noteUnsynced,
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 24),
        margin: const EdgeInsets.only(left: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: appearance.colors.surface.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(AnchorTokens.radiusPill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 4,
          children: [
            Icon(
              LucideIcons.cloudOff,
              size: AnchorTokens.sizeIconSmall,
              color: appearance.colors.muted,
            ),
            if (!isCompact)
              Text(
                context.l10n.noteOnThisPhone,
                style: AppTypography.footnote.copyWith(
                  color: appearance.colors.muted,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReminderButton extends StatelessWidget {
  const _ReminderButton({required this.reminder, required this.onPressed});

  final NoteReminder? reminder;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    final reminder = this.reminder;
    if (reminder == null) {
      return BarButton(
        icon: LucideIcons.bell,
        label: context.l10n.reminderAdd,
        onPressed: onPressed,
      );
    }
    final isOverdue = isReminderOverdue(reminder);
    return BarButton(
      icon: isOverdue ? LucideIcons.bellRing : LucideIcons.bell,
      label: reminderSpokenLabel(reminder, context.l10n),
      color: isOverdue ? colors.statusLate : colors.accentStrong,
      onPressed: onPressed,
    );
  }
}
