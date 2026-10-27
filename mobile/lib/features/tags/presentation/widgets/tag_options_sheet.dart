import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/context_extensions.dart';
import '../../../../core/theme/tokens/app_icon_sizes.dart';
import '../../../../core/theme/tokens/app_radius.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../data/repository/tags_repository.dart';
import '../../domain/tag.dart';

enum TagSheetAction { rename, delete }

/// Long-press menu for a tag. Pops with the chosen [TagSheetAction] so the
/// caller can present the follow-up sheet; a colour picked here is saved at
/// once, and the sheet stays open.
class TagOptionsSheet extends ConsumerStatefulWidget {
  const TagOptionsSheet({super.key, required this.tag});

  final Tag tag;

  static Future<TagSheetAction?> show(BuildContext context, Tag tag) {
    return AppBottomSheet.show<TagSheetAction>(
      context,
      builder: (_) => TagOptionsSheet(tag: tag),
    );
  }

  @override
  ConsumerState<TagOptionsSheet> createState() => _TagOptionsSheetState();
}

class _TagOptionsSheetState extends ConsumerState<TagOptionsSheet> {
  late String? _color = widget.tag.color;

  Tag get tag => widget.tag;

  void _setColor(String color) {
    if (color == _color) return;
    HapticFeedback.selectionClick();
    setState(() => _color = color);
    ref.read(tagsRepositoryProvider).updateTag(tag.copyWith(color: color));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dims = context.dims;
    final tagColor = parseTagColor(_color, fallback: theme.colorScheme.primary);

    return AppBottomSheet(
      icon: LucideIcons.hash,
      iconColor: tagColor,
      title: tag.name,
      subtitle: '${tag.noteCount} notes',
      contentPadding: EdgeInsets.fromLTRB(dims.xl, 0, dims.xl, dims.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ColorPicker(selected: _color, onSelected: _setColor),
          SizedBox(height: dims.md),
          _SheetAction(
            icon: LucideIcons.pencil,
            label: 'Rename tag',
            onTap: () => Navigator.pop(context, TagSheetAction.rename),
          ),
          SizedBox(height: dims.xs),
          _SheetAction(
            icon: LucideIcons.trash2,
            label: 'Delete tag',
            isDestructive: true,
            onTap: () => Navigator.pop(context, TagSheetAction.delete),
          ),
        ],
      ),
    );
  }
}

/// The tag colours as swatches; the tag's own has a check.
class _ColorPicker extends StatelessWidget {
  const _ColorPicker({required this.selected, required this.onSelected});

  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final (i, stored) in tagColors.indexed)
            _Swatch(
              name: tagColorNames[i],
              color: parseTagColor(stored),
              isSelected: selected?.toUpperCase() == stored,
              ring: theme.colorScheme.onSurface,
              onTap: () => onSelected(stored),
            ),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.name,
    required this.color,
    required this.isSelected,
    required this.ring,
    required this.onTap,
  });

  final String name;
  final Color color;
  final bool isSelected;
  final Color ring;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: name,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? ring : Colors.transparent,
              width: 2,
            ),
          ),
          child: isSelected
              ? const Icon(LucideIcons.check, size: 16, color: Colors.white)
              : null,
        ),
      ),
    );
  }
}

class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isDestructive
        ? theme.colorScheme.error
        : theme.colorScheme.onSurface;

    return Material(
      color: Colors.transparent,
      borderRadius: AppRadius.buttonBorder,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.buttonBorder,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: context.dims.md,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
            borderRadius: AppRadius.buttonBorder,
            border: Border.all(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: AppIconSizes.md,
                color: color.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 14),
              Text(
                label,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Icon(
                LucideIcons.chevronRight,
                size: 18,
                color: color.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
