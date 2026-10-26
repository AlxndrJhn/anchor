import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/gestures.dart' show kDoubleTapTimeout;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:anchor/core/network/connectivity_provider.dart';
import 'package:anchor/core/notifications/reminder_permission_prompt.dart';
import 'package:anchor/core/notifications/reminder_permissions.dart';
import 'package:anchor/core/widgets/app_drawer.dart';
import 'package:anchor/core/widgets/app_snackbar.dart';
import 'package:anchor/features/tags/presentation/tags_controller.dart';
import 'package:anchor/features/tags/domain/tag.dart';
import 'package:anchor/features/notes/presentation/widgets/note_card.dart';
import 'package:anchor/features/notes/presentation/widgets/notes_search_bar.dart';
import 'package:anchor/features/notes/presentation/widgets/note_filters_sheet.dart';
import 'package:anchor/features/notes/presentation/widgets/selection_app_bar_actions.dart';
import 'package:anchor/features/notes/presentation/widgets/reorderable_note_card.dart';
import 'package:anchor/features/notes/data/repository/notes_repository.dart';
import 'package:anchor/core/widgets/app_empty_state.dart';
import 'package:anchor/core/widgets/masonry/reorderable_masonry_grid.dart';
import 'package:anchor/core/widgets/gradient_background.dart';
import 'package:anchor/features/notes/domain/note.dart';
import 'package:anchor/features/sync/presentation/sync_warning.dart';
import 'package:anchor/core/update/update_sheet.dart';
import 'note_search.dart';
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

  /// A note being dragged to a new place: the order its section would take
  /// if it were let go now. Once let go it is [_settling] until the list
  /// itself has that order, so nothing flashes back to the old one.
  ({String group, String draggedId, List<String> ids, List<String> start})?
  _drag;
  bool _settling = false;
  DateTime _lastShuffle = DateTime(0);

  /// No new place until the cards have moved out of the way.
  static const _shuffleCooldown = Duration(milliseconds: 280);
  static const _settleTimeout = Duration(seconds: 2);

  void _onDragStarted(String group, String noteId, List<Note> notes) {
    final ids = [for (final n in notes) n.id];
    setState(() {
      _settling = false;
      _drag = (group: group, draggedId: noteId, ids: ids, start: ids);
    });
  }

  void _onDragHover(String group, String draggedId, String targetId) {
    final drag = _drag;
    if (drag == null || _settling || drag.group != group) return;
    if (drag.draggedId != draggedId) return;
    final now = DateTime.now();
    if (now.difference(_lastShuffle) < _shuffleCooldown) return;
    final from = drag.ids.indexOf(draggedId);
    final to = drag.ids.indexOf(targetId);
    if (from < 0 || to < 0 || from == to) return;
    final ids = [...drag.ids]
      ..removeAt(from)
      ..insert(to, draggedId);
    _lastShuffle = now;
    HapticFeedback.selectionClick();
    setState(
      () => _drag = (
        group: drag.group,
        draggedId: drag.draggedId,
        ids: ids,
        start: drag.start,
      ),
    );
  }

  /// Let go: the note goes between its new neighbours.
  void _onDragEnded(List<Note> notes) {
    final drag = _drag;
    if (drag == null) return;
    if (listEquals(drag.ids, drag.start)) {
      setState(() => _drag = null);
      return;
    }
    final byId = {for (final n in notes) n.id: n};
    final index = drag.ids.indexOf(drag.draggedId);
    final position = positionBetween(
      index > 0 ? byId[drag.ids[index - 1]] : null,
      index + 1 < drag.ids.length ? byId[drag.ids[index + 1]] : null,
    );
    setState(() => _settling = true);
    ref.read(notesRepositoryProvider).setPosition(drag.draggedId, position);
    Future.delayed(_settleTimeout, () {
      if (mounted && _settling && identical(_drag, drag)) {
        setState(() {
          _drag = null;
          _settling = false;
        });
      }
    });
  }

  /// [notes] in the order a drag is showing, if one is under way in [group].
  List<Note> _inDragOrder(String group, List<Note> notes) {
    final drag = _drag;
    if (drag == null || drag.group != group) return notes;
    if (_settling && listEquals([for (final n in notes) n.id], drag.ids)) {
      // The list has caught up: stop holding the order.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && identical(_drag, drag)) {
          setState(() {
            _drag = null;
            _settling = false;
          });
        }
      });
      return notes;
    }
    final byId = {for (final n in notes) n.id: n};
    return [
      for (final id in drag.ids) ?byId[id],
      for (final n in notes)
        if (!drag.ids.contains(n.id)) n,
    ];
  }

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
    _checkClipboard();
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
    _newNoteTap?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Whether the clipboard holds text, checked as a finger lands on New Note.
  bool _clipboardHasText = false;

  /// A first tap on New Note, waiting to see if a second follows.
  Timer? _newNoteTap;

  Future<void> _checkClipboard() async {
    final hasText = await Clipboard.hasStrings();
    if (mounted) _clipboardHasText = hasText;
  }

  /// A tap opens a new note. With text on the clipboard, a double tap opens
  /// one with that text in it; only then does a tap wait for a second one.
  void _onNewNotePressed(String? tagId) {
    final first = _newNoteTap;
    if (first != null && first.isActive) {
      first.cancel();
      _newNoteTap = null;
      HapticFeedback.lightImpact();
      context.go('/note/new?paste=1', extra: tagId);
      return;
    }
    if (!_clipboardHasText) {
      context.go('/note/new', extra: tagId);
      return;
    }
    _newNoteTap = Timer(kDoubleTapTimeout, () {
      _newNoteTap = null;
      if (mounted) context.go('/note/new', extra: tagId);
    });
  }

  void _exitSelectionMode() {
    ref.read(selectionModeProvider.notifier).setEnabled(false);
    ref.read(selectedNoteIdsProvider.notifier).clear();
  }

  final _scaffoldKey = GlobalKey<ScaffoldState>();

  /// New note or new list, above the New Note button that was held.
  Future<void> _showNewMenu(BuildContext fabContext, String? tagId) async {
    HapticFeedback.mediumImpact();
    final box = fabContext.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(fabContext).context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null) return;
    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
    final choice = await showMenu<String>(
      context: fabContext,
      position: RelativeRect.fromLTRB(
        topLeft.dx,
        topLeft.dy - 8,
        overlay.size.width - topLeft.dx - box.size.width,
        overlay.size.height - topLeft.dy,
      ),
      items: const [
        PopupMenuItem(
          value: 'list',
          child: ListTile(
            leading: Icon(LucideIcons.listChecks),
            title: Text('New list'),
          ),
        ),
        PopupMenuItem(
          value: 'note',
          child: ListTile(
            leading: Icon(LucideIcons.stickyNote),
            title: Text('New note'),
          ),
        ),
      ],
    );
    if (!mounted || choice == null) return;
    context.go(
      choice == 'list' ? '/note/new?checklist=1' : '/note/new',
      extra: tagId,
    );
  }

  /// The note's page, carrying the search so the note marks its matches.
  String _noteLocation(Note note) {
    final query = ref.read(searchQueryProvider).trim();
    return Uri(
      path: '/note/${note.id}',
      queryParameters: query.isEmpty ? null : {'hl': query},
    ).toString();
  }

  /// When Back last asked to be pressed again to leave the app.
  DateTime? _exitAskedAt;

  /// Back steps out of selection, then the search, and only leaves the app
  /// when pressed twice, so a stray press doesn't close it.
  void _onBack(bool isSelectionMode, String searchQuery) {
    final scaffold = _scaffoldKey.currentState;
    if (scaffold?.isDrawerOpen ?? false) return scaffold!.closeDrawer();
    if (isSelectionMode) return _exitSelectionMode();
    if (searchQuery.isNotEmpty) {
      _searchController.clear();
      ref.read(searchQueryProvider.notifier).set('');
      return;
    }
    final now = DateTime.now();
    final asked = _exitAskedAt;
    if (asked != null && now.difference(asked) < _exitWindow) {
      SystemNavigator.pop();
      return;
    }
    _exitAskedAt = now;
    AppSnackbar.showInfo(
      context,
      message: 'Press back again to exit',
      icon: LucideIcons.logOut,
    );
  }

  static const _exitWindow = Duration(seconds: 2);

  Future<void> _onRefresh() async {
    await ref.read(notesControllerProvider.notifier).sync();
  }

  Widget _buildNoteItem(
    Note note,
    bool isSelectionMode,
    Set<String> selectedNoteIds, {
    bool canDrag = false,
  }) {
    return NoteCard(
      note: note,
      isSelectionMode: isSelectionMode,
      isSelected: selectedNoteIds.contains(note.id),
      // While notes can be dragged, the drag's own hold selects instead.
      onLongPress: canDrag
          ? null
          : () {
              if (!isSelectionMode) {
                ref.read(selectionModeProvider.notifier).setEnabled(true);
              }
              ref.read(selectedNoteIdsProvider.notifier).toggle(note.id);
            },
      onTap: () {
        if (isSelectionMode) {
          ref.read(selectedNoteIdsProvider.notifier).toggle(note.id);
        } else {
          context.go(_noteLocation(note), extra: note);
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
    bool lazy = true,
    String? reorderGroup,
    List<Note>? reorderNotes,
  }) {
    final dims = context.dims;
    Widget card(Note note) => selectable
        ? _buildNoteItem(
            note,
            isSelectionMode,
            selectedNoteIds,
            canDrag: reorderGroup != null,
          )
        : NoteCard(
            note: note,
            isSelectionMode: false,
            isSelected: false,
            onLongPress: () {},
            onTap: () => context.go(_noteLocation(note), extra: note),
          );
    Widget item(Note note) => reorderGroup == null
        ? KeyedSubtree(key: ValueKey(note.id), child: card(note))
        : ReorderableNoteCard(
            // Keyed by note, so the card in hand survives the reordering.
            key: ValueKey(note.id),
            noteId: note.id,
            group: reorderGroup,
            onDragStarted: () =>
                _onDragStarted(reorderGroup, note.id, reorderNotes ?? notes),
            onHover: (draggedId) =>
                _onDragHover(reorderGroup, draggedId, note.id),
            onDragEnded: () => _onDragEnded(reorderNotes ?? notes),
            onHeld: () {
              ref.read(selectionModeProvider.notifier).setEnabled(true);
              ref.read(selectedNoteIdsProvider.notifier).toggle(note.id);
            },
            child: card(note),
          );
    int? indexOf(Key key) {
      final index = notes.indexWhere((n) => ValueKey(n.id) == key);
      return index < 0 ? null : index;
    }

    // Stays right when cards change places (a drag), unlike the package's
    // masonry grid; see ReorderableMasonryGrid.
    Widget masonry() => ReorderableMasonryGrid(
      ids: [for (final n in notes) n.id],
      gridDelegate: const SliverSimpleGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
      ),
      mainAxisSpacing: dims.gridSpacing,
      crossAxisSpacing: dims.gridSpacing,
      delegate: SliverChildBuilderDelegate(
        (context, index) => item(notes[index]),
        childCount: notes.length,
        findChildIndexCallback: indexOf,
      ),
    );

    return SliverPadding(
      padding: dims.screenInsets.copyWith(
        top: underLabel ? dims.sm : dims.screenGutter,
      ),
      // Only one lazy masonry grid per list: two of them keep correcting
      // each other's estimated height, and the list can't reach its end.
      // The short sections (pinned, archived) are laid out in full.
      sliver: viewOptions.viewType == ViewType.grid && !lazy
          ? SliverToBoxAdapter(
              child: CustomScrollView(
                shrinkWrap: true,
                primary: false,
                physics: const NeverScrollableScrollPhysics(),
                slivers: [masonry()],
              ),
            )
          : viewOptions.viewType == ViewType.grid
          ? masonry()
          : SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => Padding(
                  key: ValueKey(notes[index].id),
                  padding: EdgeInsets.only(bottom: dims.listItemSpacing),
                  child: item(notes[index]),
                ),
                childCount: notes.length,
                findChildIndexCallback: indexOf,
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(notesControllerProvider);
    final searchQuery = ref.watch(searchQueryProvider);
    final filters = ref.watch(noteFiltersControllerProvider);
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
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _onBack(isSelectionMode, searchQuery);
      },
      child: Scaffold(
        key: _scaffoldKey,
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
                      // Selecting without a long press, which now drags.
                      IconButton(
                        icon: const Icon(LucideIcons.squareCheck),
                        tooltip: 'Select notes',
                        onPressed: () => ref
                            .read(selectionModeProvider.notifier)
                            .setEnabled(true),
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
                        const UpdateBanner(),
                        NotesSearchBar(
                          controller: _searchController,
                          query: searchQuery,
                          onChanged: (value) =>
                              ref.read(searchQueryProvider.notifier).set(value),
                          onClear: () {
                            _searchController.clear();
                            ref.read(searchQueryProvider.notifier).set('');
                          },
                          filterCount:
                              filters.count + (selectedTagId != null ? 1 : 0),
                          onFilter: () => AppBottomSheet.show(
                            context,
                            builder: (context) => const NoteFiltersSheet(),
                          ),
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
                // Each section is its own sliver here: grouped, the masonry
                // grids' estimated heights stop scrolling short of the end.
                ...notesAsync.when(
                  data: (notes) {
                    final q = searchQuery.trim().toLowerCase();
                    bool matches(Note note) =>
                        filters.matches(note) && noteMatchesSearch(note, q);

                    final filteredNotes = notes.where(matches).toList();
                    // A search, or a tag (whose count includes them), also
                    // lists archived notes after the others, as Google Keep
                    // does.
                    final withArchived =
                        q.isNotEmpty ||
                        selectedTagId != null ||
                        !filters.isEmpty;
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
                      if (searchQuery.isNotEmpty || !filters.isEmpty) {
                        return const [
                          SliverAppEmptyState(
                            icon: LucideIcons.search,
                            message: 'No matching notes found',
                          ),
                        ];
                      }
                      return const [
                        SliverAppEmptyState(
                          icon: LucideIcons.sparkles,
                          message: 'Capture your ideas here',
                        ),
                      ];
                    }

                    if (viewOptions == null) {
                      return const [
                        SliverToBoxAdapter(child: SizedBox.shrink()),
                      ];
                    }

                    final comparator = noteComparator(viewOptions);
                    filteredNotes.sort(comparator);
                    archivedMatches.sort(comparator);

                    // Pinned and other notes get headings, as on the web.
                    final sortedPinned = filteredNotes
                        .where((n) => n.isPinned)
                        .toList();
                    final sortedOthers = filteredNotes
                        .where((n) => !n.isPinned)
                        .toList();
                    // Notes can be dragged to new places in the default
                    // order, as on the web, while the whole list is shown.
                    final canReorder =
                        viewOptions.sortOption == SortOption.dateModified &&
                        !viewOptions.isAscending &&
                        !isSelectionMode &&
                        q.isEmpty &&
                        filters.isEmpty;
                    final pinned = _inDragOrder('pinned', sortedPinned);
                    final others = _inDragOrder('others', sortedOthers);
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

                    return [
                      if (pinned.isNotEmpty) ...[
                        label(LucideIcons.pin, 'Pinned', pinned.length),
                        _notesSliver(
                          pinned,
                          viewOptions,
                          isSelectionMode,
                          selectedNoteIds,
                          underLabel: true,
                          lazy: others.isEmpty,
                          reorderGroup: canReorder ? 'pinned' : null,
                          reorderNotes: sortedPinned,
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
                          reorderGroup: canReorder ? 'others' : null,
                          reorderNotes: sortedOthers,
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
                          lazy: filteredNotes.isEmpty,
                        ),
                      ],
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: isSelectionMode ? 0 : _fabClearance,
                        ),
                      ),
                    ];
                  },
                  loading: () => const [
                    SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ],
                  error: (err, stack) => [
                    SliverFillRemaining(
                      child: Center(child: Text('Error: $err')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        floatingActionButton: isSelectionMode
            ? null
            : Builder(
                // Holding the button offers a new list as well, as in
                // Google Keep; double-tapping it pastes the clipboard into a
                // new note.
                builder: (fabContext) => Listener(
                  onPointerDown: (_) => _checkClipboard(),
                  child: GestureDetector(
                    onLongPress: () => _showNewMenu(fabContext, selectedTagId),
                    child: FloatingActionButton.extended(
                      onPressed: () => _onNewNotePressed(selectedTagId),
                      icon: const Icon(LucideIcons.plus),
                      label: const Text('New Note'),
                    ),
                  ),
                ),
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
