import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:anchor/core/network/connectivity_provider.dart';
import 'package:anchor/core/notifications/reminder_permission_prompt.dart';
import 'package:anchor/core/notifications/reminder_permissions.dart';
import 'package:anchor/core/widgets/quill_preview.dart';
import 'package:anchor/core/widgets/app_drawer.dart';
import 'package:anchor/features/tags/presentation/tags_controller.dart';
import 'package:anchor/features/tags/domain/tag.dart';
import 'package:anchor/features/notes/presentation/widgets/note_card.dart';
import 'package:anchor/features/notes/presentation/widgets/notes_search_bar.dart';
import 'package:anchor/features/notes/presentation/widgets/selection_app_bar_actions.dart';
import 'package:anchor/core/widgets/app_empty_state.dart';
import 'package:anchor/core/widgets/gradient_background.dart';
import 'package:anchor/features/notes/domain/note.dart';
import 'package:anchor/features/sync/presentation/sync_warning.dart';
import 'notes_controller.dart';
import 'notes_view_options.dart';
import 'widgets/view_options_sheet.dart';
import '../../../core/theme/context_extensions.dart';
import '../../../core/theme/tokens/app_icon_sizes.dart';
import '../../../core/theme/tokens/app_radius.dart';
import 'package:anchor/core/widgets/app_bottom_sheet.dart';
import 'package:anchor/core/widgets/app_bar_scrim.dart';
import 'package:anchor/core/widgets/large_title_app_bar.dart';

class NotesListScreen extends ConsumerStatefulWidget {
  const NotesListScreen({super.key});

  @override
  ConsumerState<NotesListScreen> createState() => _NotesListScreenState();
}

class _NotesListScreenState extends ConsumerState<NotesListScreen> {
  final _searchController = TextEditingController();

  /// Height of an extended FAB, which Material does not export.
  static const double _extendedFabHeight = 56;

  /// Room under the last card for the FAB floating over it.
  static const double _fabClearance =
      _extendedFabHeight + kFloatingActionButtonMargin;

  @override
  void initState() {
    super.initState();
    // Sync controller with provider state if it exists
    final currentQuery = ref.read(searchQueryProvider);
    if (currentQuery.isNotEmpty) {
      _searchController.text = currentQuery;
    }
  }

  /// Asks for what a reminder needs the first time this device holds one.
  void _maybeAskForReminderPermissions(List<Note> notes) {
    final controller = ref.read(reminderPermissionsControllerProvider.notifier);
    if (controller.promptedThisRun) return;

    final permissions = ref.read(reminderPermissionsControllerProvider).value;
    if (permissions == null || permissions.ringsOnTime) return;

    final rings = notes.any(
      (note) => note.hasReminder && note.isActive && !note.isArchived,
    );
    if (!rings) return;

    controller.promptedThisRun = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ensureReminderPermissions(
        context,
        ref,
        trigger: ReminderPermissionTrigger.synced,
      );
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _exitSelectionMode() {
    ref.read(selectionModeProvider.notifier).setEnabled(false);
    ref.read(selectedNoteIdsProvider.notifier).clear();
  }

  Future<void> _onRefresh() async {
    await ref.read(notesControllerProvider.notifier).sync();
  }

  Widget _buildNoteItem(
    Note note,
    bool isSelectionMode,
    Set<String> selectedNoteIds,
  ) {
    return NoteCard(
      note: note,
      isSelectionMode: isSelectionMode,
      isSelected: selectedNoteIds.contains(note.id),
      onLongPress: () {
        if (!isSelectionMode) {
          ref.read(selectionModeProvider.notifier).setEnabled(true);
        }
        ref.read(selectedNoteIdsProvider.notifier).toggle(note.id);
      },
      onTap: () {
        if (isSelectionMode) {
          ref.read(selectedNoteIdsProvider.notifier).toggle(note.id);
        } else {
          context.go('/note/${note.id}', extra: note);
        }
      },
    );
  }

  Widget _notesSliver(
    List<Note> notes,
    NotesViewOptions viewOptions,
    bool isSelectionMode,
    Set<String> selectedNoteIds, {
    bool selectable = true,
    bool underLabel = false,
  }) {
    final dims = context.dims;
    Widget item(Note note) => selectable
        ? _buildNoteItem(note, isSelectionMode, selectedNoteIds)
        : NoteCard(
            note: note,
            isSelectionMode: false,
            isSelected: false,
            onLongPress: () {},
            onTap: () => context.go('/note/${note.id}', extra: note),
          );
    return SliverPadding(
      padding: dims.screenInsets.copyWith(
        top: underLabel ? dims.sm : dims.screenGutter,
      ),
      sliver: viewOptions.viewType == ViewType.grid
          ? SliverMasonryGrid.count(
              crossAxisCount: 2,
              mainAxisSpacing: dims.gridSpacing,
              crossAxisSpacing: dims.gridSpacing,
              childCount: notes.length,
              itemBuilder: (context, index) => item(notes[index]),
            )
          : SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => Padding(
                  padding: EdgeInsets.only(bottom: dims.listItemSpacing),
                  child: item(notes[index]),
                ),
                childCount: notes.length,
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(notesControllerProvider);
    final searchQuery = ref.watch(searchQueryProvider);
    ref.watch(reminderPermissionsControllerProvider);
    final notes = notesAsync.value;
    if (notes != null) _maybeAskForReminderPermissions(notes);
    final selectedTagId = ref.watch(selectedTagFilterProvider);
    final tagsAsync = ref.watch(tagsControllerProvider);
    final isSyncing = ref.watch(syncManagerProvider);
    final isSelectionMode = ref.watch(selectionModeProvider);
    final selectedNoteIds = ref.watch(selectedNoteIdsProvider);
    final viewOptionsAsync = ref.watch(notesViewOptionsProvider);
    final viewOptions = viewOptionsAsync.value;
    final theme = Theme.of(context);
    final dims = context.dims;

    // Get selected tag
    Tag? selectedTag;
    if (selectedTagId != null && tagsAsync.hasValue) {
      selectedTag = tagsAsync.value
          ?.where((t) => t.id == selectedTagId)
          .firstOrNull;
    }

    return PopScope(
      canPop: !isSelectionMode,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && isSelectionMode) {
          _exitSelectionMode();
        }
      },
      child: Scaffold(
        drawer: const AppDrawer(),
        body: ContentBackground(
          child: RefreshIndicator.adaptive(
            onRefresh: _onRefresh,
            displacement: 20,
            edgeOffset: dims.appBarExpandedHeight,
            color: theme.colorScheme.primary,
            child: CustomScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  floating: true,
                  pinned: true,
                  expandedHeight: isSelectionMode
                      ? kToolbarHeight
                      : dims.appBarExpandedHeight,
                  toolbarHeight: kToolbarHeight,
                  scrolledUnderElevation: 0,
                  leading: isSelectionMode
                      ? IconButton(
                          icon: const Icon(LucideIcons.x),
                          onPressed: _exitSelectionMode,
                          tooltip: 'Cancel',
                        )
                      : Builder(
                          builder: (context) => IconButton(
                            icon: const Icon(LucideIcons.menu),
                            onPressed: () => Scaffold.of(context).openDrawer(),
                            tooltip: 'Menu',
                          ),
                        ),
                  flexibleSpace: Stack(
                    fit: StackFit.expand,
                    children: [
                      const AppBarScrim(),
                      if (!isSelectionMode)
                        FlexibleSpaceBar(
                          centerTitle: Platform.isIOS,
                          expandedTitleScale:
                              LargeTitleAppBar.expandedTitleScale,
                          titlePadding: EdgeInsets.only(
                            left: LargeTitleAppBar.titleInset,
                            right: Platform.isIOS
                                ? LargeTitleAppBar.titleInset
                                : 0,
                            bottom: dims.sm,
                          ),
                          title: Text(
                            'Anchor',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                    ],
                  ),
                  title: isSelectionMode
                      ? Text(
                          selectedNoteIds.isEmpty
                              ? 'Select notes'
                              : '${selectedNoteIds.length} ${selectedNoteIds.length == 1 ? 'note' : 'notes'}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : null,
                  actions: [
                    if (isSelectionMode)
                      SelectionAppBarActions(
                        selectedNoteIds: selectedNoteIds,
                        onExitSelectionMode: _exitSelectionMode,
                      )
                    else ...[
                      // Only show sync indicator when actively syncing
                      if (isSyncing)
                        Padding(
                          padding: EdgeInsets.only(right: dims.xs),
                          child: Center(child: _SyncIndicator(theme: theme)),
                        ),
                      if (viewOptions != null)
                        IconButton(
                          icon: Icon(
                            viewOptions.viewType == ViewType.grid
                                ? LucideIcons.layoutGrid
                                : LucideIcons.list,
                          ),
                          tooltip: 'View options',
                          onPressed: () {
                            AppBottomSheet.show(
                              context,
                              builder: (context) => const ViewOptionsSheet(),
                            );
                          },
                        ),
                    ],
                  ],
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    dims.screenGutter,
                    dims.xs,
                    dims.screenGutter,
                    0,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SyncWarning(),
                        NotesSearchBar(
                          controller: _searchController,
                          query: searchQuery,
                          onChanged: (value) =>
                              ref.read(searchQueryProvider.notifier).set(value),
                          onClear: () {
                            _searchController.clear();
                            ref.read(searchQueryProvider.notifier).set('');
                          },
                        ),
                        // Tag filter indicator
                        if (selectedTag != null) ...[
                          SizedBox(height: dims.sm),
                          _TagFilterChip(
                            tag: selectedTag,
                            onClear: () {
                              ref
                                  .read(selectedTagFilterProvider.notifier)
                                  .clear();
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                notesAsync.when(
                  data: (notes) {
                    final q = searchQuery.trim().toLowerCase();
                    bool matches(Note note) {
                      if (q.isEmpty) return true;
                      final contentText = extractPlainTextFromQuillContent(
                        note.content,
                      ).toLowerCase();
                      return note.title.toLowerCase().contains(q) ||
                          contentText.contains(q);
                    }

                    final filteredNotes = notes.where(matches).toList();
                    // A search, or a tag (whose count includes them), also
                    // lists archived notes after the others, as Google Keep
                    // does.
                    final withArchived = q.isNotEmpty || selectedTagId != null;
                    final archivedMatches = !withArchived
                        ? <Note>[]
                        : (ref.watch(archiveControllerProvider).value ??
                                  const <Note>[])
                              .where(
                                (note) =>
                                    (selectedTagId == null ||
                                        note.tagIds.contains(selectedTagId)) &&
                                    matches(note),
                              )
                              .toList();

                    if (filteredNotes.isEmpty && archivedMatches.isEmpty) {
                      if (searchQuery.isNotEmpty) {
                        return const SliverAppEmptyState(
                          icon: LucideIcons.search,
                          message: 'No matching notes found',
                        );
                      }
                      return const SliverAppEmptyState(
                        icon: LucideIcons.sparkles,
                        message: 'Capture your ideas here',
                      );
                    }

                    if (viewOptions == null) {
                      return const SliverToBoxAdapter(child: SizedBox.shrink());
                    }

                    final comparator = noteComparator(viewOptions);
                    filteredNotes.sort(comparator);
                    archivedMatches.sort(comparator);

                    // Pinned and other notes get headings, as on the web.
                    final pinned = filteredNotes
                        .where((n) => n.isPinned)
                        .toList();
                    final others = filteredNotes
                        .where((n) => !n.isPinned)
                        .toList();
                    Widget label(IconData icon, String text, int count) =>
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            dims.screenGutter,
                            dims.sm,
                            dims.screenGutter,
                            0,
                          ),
                          sliver: SliverToBoxAdapter(
                            child: _SectionLabel(
                              icon: icon,
                              label: text,
                              count: count,
                            ),
                          ),
                        );

                    return SliverMainAxisGroup(
                      slivers: [
                        if (pinned.isNotEmpty) ...[
                          label(LucideIcons.pin, 'Pinned', pinned.length),
                          _notesSliver(
                            pinned,
                            viewOptions,
                            isSelectionMode,
                            selectedNoteIds,
                            underLabel: true,
                          ),
                        ],
                        if (others.isNotEmpty) ...[
                          if (pinned.isNotEmpty)
                            label(
                              LucideIcons.stickyNote,
                              'Others',
                              others.length,
                            ),
                          _notesSliver(
                            others,
                            viewOptions,
                            isSelectionMode,
                            selectedNoteIds,
                            underLabel: pinned.isNotEmpty,
                          ),
                        ],
                        if (archivedMatches.isNotEmpty) ...[
                          label(
                            LucideIcons.archive,
                            'Archived',
                            archivedMatches.length,
                          ),
                          _notesSliver(
                            archivedMatches,
                            viewOptions,
                            false,
                            const <String>{},
                            selectable: false,
                            underLabel: true,
                          ),
                        ],
                        SliverToBoxAdapter(
                          child: SizedBox(
                            height: isSelectionMode ? 0 : _fabClearance,
                          ),
                        ),
                      ],
                    );
                  },
                  loading: () => const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (err, stack) => SliverFillRemaining(
                    child: Center(child: Text('Error: $err')),
                  ),
                ),
              ],
            ),
          ),
        ),
        floatingActionButton: isSelectionMode
            ? null
            : FloatingActionButton.extended(
                onPressed: () => context.go('/note/new', extra: selectedTagId),
                icon: const Icon(LucideIcons.plus),
                label: const Text('New Note'),
              ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;

  const _SectionLabel({
    required this.icon,
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    return Row(
      children: [
        Icon(icon, size: AppIconSizes.xs, color: color),
        const SizedBox(width: 6),
        Text(
          '${label.toUpperCase()}  $count',
          style: theme.textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }
}

class _TagFilterChip extends StatelessWidget {
  final Tag tag;
  final VoidCallback onClear;

  const _TagFilterChip({required this.tag, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dims = context.dims;
    final tagColor = parseTagColor(
      tag.color,
      fallback: theme.colorScheme.primary,
    );

    return Container(
      padding: EdgeInsets.symmetric(horizontal: dims.xxs, vertical: dims.xxs),
      decoration: BoxDecoration(
        color: tagColor.withValues(alpha: 0.1),
        borderRadius: AppRadius.smBorder,
        border: Border.all(color: tagColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons.filter,
                  size: AppIconSizes.xs,
                  color: tagColor,
                ),
                const SizedBox(width: 6),
                Text(
                  'Filtering by',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: dims.xs,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: tagColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.hash, size: 12, color: tagColor),
                      const SizedBox(width: 2),
                      Text(
                        tag.name,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: tagColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: Colors.transparent,
            borderRadius: AppRadius.xsBorder,
            child: InkWell(
              onTap: onClear,
              borderRadius: AppRadius.xsBorder,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  LucideIcons.x,
                  size: AppIconSizes.sm,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncIndicator extends StatefulWidget {
  final ThemeData theme;

  const _SyncIndicator({required this.theme});

  @override
  State<_SyncIndicator> createState() => _SyncIndicatorState();
}

class _SyncIndicatorState extends State<_SyncIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _rotation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.linear));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _rotation,
      child: Icon(
        LucideIcons.refreshCw,
        size: AppIconSizes.md,
        color: widget.theme.colorScheme.onSurface,
      ),
    );
  }
}
