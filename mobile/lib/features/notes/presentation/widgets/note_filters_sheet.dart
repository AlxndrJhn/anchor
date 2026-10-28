import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/context_extensions.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_section_header.dart';
import '../../../tags/presentation/tags_controller.dart';
import '../../domain/note_filters.dart';
import '../note_search.dart';
import '../notes_controller.dart';
import 'note_background.dart';

/// Filters for the notes list: what a note has, its colour and its tag.
class NoteFiltersSheet extends ConsumerWidget {
  const NoteFiltersSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dims = context.dims;
    final theme = Theme.of(context);
    final filters = ref.watch(noteFiltersControllerProvider);
    final notifier = ref.read(noteFiltersControllerProvider.notifier);
    final tagId = ref.watch(selectedTagFilterProvider);
    final tags = ref.watch(tagsControllerProvider).value ?? const [];
    final search = ref.watch(searchOptionsProvider);
    final active = filters.count + (tagId != null ? 1 : 0);

    Widget section(String title) => Padding(
      padding: EdgeInsets.fromLTRB(dims.xl, dims.lg, dims.xl, dims.sm),
      child: AppSectionHeader(title: title, padding: EdgeInsets.zero),
    );

    Widget kind(String label, IconData icon, bool on, NoteFilters next) =>
        FilterChip(
          avatar: Icon(icon, size: 16),
          label: Text(label),
          selected: on,
          showCheckmark: false,
          onSelected: (_) => notifier.set(next),
        );

    return AppBottomSheet(
      maxHeightFactor: 0.8,
      icon: LucideIcons.listFilter,
      title: 'Filter notes',
      subtitle: active == 0 ? 'Show only notes that…' : '$active on',
      showDone: true,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Always shown (disabled when idle) so toggling the first filter
            // doesn't shift the rest of the sheet down.
            Padding(
              padding: EdgeInsets.symmetric(horizontal: dims.xl),
              child: TextButton.icon(
                icon: const Icon(LucideIcons.x, size: 16),
                label: const Text('Clear filters'),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.onSurface,
                ),
                onPressed: active == 0
                    ? null
                    : () {
                        notifier.clear();
                        ref.read(selectedTagFilterProvider.notifier).clear();
                      },
              ),
            ),
            section('Has'),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: dims.xl),
              child: Wrap(
                spacing: dims.sm,
                runSpacing: dims.sm,
                children: [
                  kind(
                    'Pictures',
                    LucideIcons.image,
                    filters.picture,
                    filters.copyWith(picture: !filters.picture),
                  ),
                  kind(
                    'Checklists',
                    LucideIcons.listChecks,
                    filters.checklist,
                    filters.copyWith(checklist: !filters.checklist),
                  ),
                  kind(
                    'Reminders',
                    LucideIcons.bell,
                    filters.reminder,
                    filters.copyWith(reminder: !filters.reminder),
                  ),
                  kind(
                    'Contains secret',
                    LucideIcons.keyRound,
                    filters.secret,
                    filters.copyWith(secret: !filters.secret),
                  ),
                ],
              ),
            ),
            section('Search'),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: dims.xl),
              child: Wrap(
                spacing: dims.sm,
                runSpacing: dims.sm,
                children: [
                  FilterChip(
                    avatar: const Icon(LucideIcons.regex, size: 16),
                    label: const Text('Regular expression'),
                    selected: search.regex,
                    showCheckmark: false,
                    onSelected: (on) => ref
                        .read(searchOptionsProvider.notifier)
                        .set(search.copyWith(regex: on)),
                  ),
                  FilterChip(
                    avatar: const Icon(LucideIcons.caseSensitive, size: 16),
                    label: const Text('Match case'),
                    selected: search.matchCase,
                    showCheckmark: false,
                    onSelected: (on) => ref
                        .read(searchOptionsProvider.notifier)
                        .set(search.copyWith(matchCase: on)),
                  ),
                ],
              ),
            ),
            section('Colour'),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: dims.xl),
              child: Wrap(
                spacing: dims.sm,
                runSpacing: dims.sm,
                children: [
                  for (final style in NoteBackgroundStyle.styles)
                    _Swatch(
                      id: style.id,
                      selected: filters.background == style.id,
                      onTap: () => notifier.set(
                        filters.copyWith(
                          background: () =>
                              filters.background == style.id ? null : style.id,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (tags.isNotEmpty) ...[
              section('Tag'),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: dims.xl),
                child: Wrap(
                  spacing: dims.sm,
                  runSpacing: dims.sm,
                  children: [
                    for (final tag in tags)
                      ChoiceChip(
                        avatar: const Icon(LucideIcons.hash, size: 14),
                        label: Text(tag.name),
                        selected: tag.id == tagId,
                        showCheckmark: false,
                        onSelected: (_) => ref
                            .read(selectedTagFilterProvider.notifier)
                            .select(tag.id == tagId ? null : tag.id),
                      ),
                  ],
                ),
              ),
            ],
            SizedBox(height: dims.lg),
          ],
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.id,
    required this.selected,
    required this.onTap,
  });

  final String id;
  final bool selected;
  final VoidCallback onTap;

  static const double _size = 40;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = id.split('_').skip(1).join(' ');
    return Semantics(
      button: true,
      selected: selected,
      label: name,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: _size,
          height: _size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected
                  ? theme.colorScheme.tertiary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.15),
              width: selected ? 3 : 1,
            ),
          ),
          child: ClipOval(
            child: NoteBackground(
              styleId: id,
              child: selected
                  ? Icon(
                      LucideIcons.check,
                      size: 18,
                      color: theme.colorScheme.onSurface,
                    )
                  : const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
  }
}
