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

  @override
  Widget build(BuildContext context) {
    final leading = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PageBackButton(onPressed: onBack),
        if (isUnsynced) _UnsyncedBadge(appearance: appearance),
      ],
    );
    final actions = <Widget>[
      if (isTrashed)
        BarButton(
          icon: LucideIcons.history,
          label: context.l10n.actionHistory,
          onPressed: onHistory,
        )
      else ...[
        if (!isReadOnly)
          BarButton(
            icon: LucideIcons.palette,
            label: context.l10n.noteBackground,
            onPressed: onBackground,
          ),
        _ReminderButton(reminder: reminder, onPressed: onReminder),
        BarButton(
          icon: LucideIcons.ellipsis,
          label: context.l10n.commonMore,
          onPressed: onMore,
        ),
      ],
    ];
    return PageBar(
      color: appearance.colors.bg,
      scrollOffset: scrollOffset,
      leading: leading,
      actions: actions,
    );
  }
}

class _UnsyncedBadge extends StatelessWidget {
  const _UnsyncedBadge({required this.appearance});

  final NoteAppearance appearance;

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
