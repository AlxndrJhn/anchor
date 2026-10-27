import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/theme/context_extensions.dart';
import '../../../../core/theme/tokens/app_icon_sizes.dart';
import '../../../../core/theme/tokens/app_opacity.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';

class NoteOptionsSheet extends StatelessWidget {
  final bool isReadOnly;
  final bool isTrashed;

  /// How many people the note is shared with.
  final int shareCount;
  final VoidCallback onTagsTap;
  final VoidCallback onReminderTap;
  final VoidCallback onBackgroundTap;
  final VoidCallback onAttachmentTap;

  /// Shares the note with other users; null when the user can't.
  final VoidCallback? onShareTap;

  /// Null hides the option, for notes that have no history to read.
  final VoidCallback? onHistoryTap;

  /// Hands the note to another app as text.
  final VoidCallback onSendTap;

  /// Null hides "Make a copy", for notes not saved yet or in the trash.
  final VoidCallback? onCopyTap;

  /// Null hides these; at most one of them is given.
  final VoidCallback? onShowCheckboxesTap;
  final VoidCallback? onHideCheckboxesTap;

  /// Null hides these, for notes without ticked checklist items.
  final VoidCallback? onUncheckAllTap;
  final VoidCallback? onRemoveCheckedTap;

  /// Lock… (or Change lock… when [isLocked]); null hides it.
  final VoidCallback? onLockTap;
  final bool isLocked;

  /// Remove lock; null hides it.
  final VoidCallback? onRemoveLockTap;

  const NoteOptionsSheet({
    super.key,
    required this.isReadOnly,
    required this.isTrashed,
    this.shareCount = 0,
    required this.onTagsTap,
    required this.onReminderTap,
    required this.onBackgroundTap,
    required this.onAttachmentTap,
    this.onShareTap,
    required this.onSendTap,
    this.onCopyTap,
    this.onHistoryTap,
    this.onShowCheckboxesTap,
    this.onHideCheckboxesTap,
    this.onUncheckAllTap,
    this.onRemoveCheckedTap,
    this.onLockTap,
    this.isLocked = false,
    this.onRemoveLockTap,
  });

  static const double _maxTileWidth = 104;

  /// Scaled by the user's text scale so long labels keep their two lines.
  static const double _minTileWidth = 76;

  static const int _minColumns = 2;
  static const int _maxColumns = 5;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;

    final options = <_OptionSpec>[
      if (!isTrashed)
        _OptionSpec(icon: LucideIcons.tags, label: 'Tags', onTap: onTagsTap),
      if (!isTrashed)
        _OptionSpec(
          icon: LucideIcons.bell,
          label: 'Reminder',
          onTap: onReminderTap,
        ),
      if (!isReadOnly)
        _OptionSpec(
          icon: LucideIcons.palette,
          label: 'Background',
          onTap: onBackgroundTap,
        ),
      if (!isReadOnly)
        _OptionSpec(
          icon: LucideIcons.paperclip,
          label: 'Attachment',
          onTap: onAttachmentTap,
        ),
      if (onShowCheckboxesTap != null)
        _OptionSpec(
          icon: LucideIcons.listChecks,
          label: 'Show checkboxes',
          onTap: onShowCheckboxesTap!,
        ),
      if (onHideCheckboxesTap != null)
        _OptionSpec(
          icon: LucideIcons.list,
          label: 'Hide checkboxes',
          onTap: onHideCheckboxesTap!,
        ),
      if (onUncheckAllTap != null)
        _OptionSpec(
          icon: LucideIcons.listRestart,
          label: 'Untick all',
          onTap: onUncheckAllTap!,
        ),
      if (onRemoveCheckedTap != null)
        _OptionSpec(
          icon: LucideIcons.listX,
          label: 'Delete ticked',
          onTap: onRemoveCheckedTap!,
        ),
      if (onShareTap != null)
        _OptionSpec(
          icon: LucideIcons.userPlus,
          label: shareCount > 0 ? 'Shared with $shareCount' : 'Share',
          onTap: onShareTap!,
        ),
      _OptionSpec(icon: LucideIcons.send, label: 'Send', onTap: onSendTap),
      if (onCopyTap != null)
        _OptionSpec(
          icon: LucideIcons.copy,
          label: 'Make a copy',
          onTap: onCopyTap!,
        ),
      if (onHistoryTap != null)
        _OptionSpec(
          icon: LucideIcons.history,
          label: 'History',
          onTap: onHistoryTap!,
        ),
      if (onLockTap != null)
        _OptionSpec(
          icon: LucideIcons.lock,
          label: isLocked ? 'Change lock…' : 'Lock…',
          onTap: onLockTap!,
        ),
      if (onRemoveLockTap != null)
        _OptionSpec(
          icon: LucideIcons.lockOpen,
          label: 'Remove lock',
          onTap: onRemoveLockTap!,
        ),
    ];

    return AppBottomSheet(
      icon: LucideIcons.moreHorizontal,
      title: 'More Options',
      subtitle: 'Customize and manage your note',
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(dims.xl, 0, dims.xl, dims.xl),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final spacing = dims.sm;
            final minTile = MediaQuery.textScalerOf(
              context,
            ).scale(_minTileWidth);
            final columns = _columnsFor(
              count: options.length,
              width: constraints.maxWidth,
              minTileWidth: minTile,
              spacing: spacing,
            );
            final tileWidth = math.min(
              (constraints.maxWidth - spacing * (columns - 1)) / columns,
              _maxTileWidth,
            );

            return Wrap(
              spacing: spacing,
              runSpacing: dims.lg,
              children: [
                for (final option in options)
                  SizedBox(
                    width: tileWidth,
                    child: _GridOptionTile(option: option),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  static int _columnsFor({
    required int count,
    required double width,
    required double minTileWidth,
    required double spacing,
  }) {
    final fitting = ((width + spacing) / (minTileWidth + spacing))
        .floor()
        .clamp(_minColumns, _maxColumns);
    return math.max(math.min(count, fitting), 1);
  }
}

class _OptionSpec {
  const _OptionSpec({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class _GridOptionTile extends StatelessWidget {
  const _GridOptionTile({required this.option});

  final _OptionSpec option;

  static const double _minCircle = 52;
  static const double _maxCircle = 64;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.onSurfaceVariant;
    final labelColor = theme.colorScheme.onSurface;
    final background = theme.colorScheme.surfaceContainerHigh;

    return LayoutBuilder(
      builder: (context, constraints) {
        final circle = constraints.maxWidth.clamp(_minCircle, _maxCircle);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              color: background,
              shape: CircleBorder(
                side: BorderSide(
                  color: accent.withValues(alpha: AppOpacity.hairline),
                  width: 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () {
                  Navigator.pop(context);
                  option.onTap();
                },
                highlightColor: accent.withValues(alpha: AppOpacity.activeFill),
                splashColor: accent.withValues(alpha: AppOpacity.activeFill),
                child: SizedBox(
                  width: circle,
                  height: circle,
                  child: Center(
                    child: Icon(
                      option.icon,
                      size: AppIconSizes.lg,
                      color: accent,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: context.dims.xs),
            Text(
              option.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: labelColor,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ],
        );
      },
    );
  }
}
