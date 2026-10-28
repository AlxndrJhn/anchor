import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:anchor/core/theme/context_extensions.dart';
import 'package:anchor/core/widgets/app_empty_state.dart';
import 'package:anchor/core/widgets/app_page_scaffold.dart';
import 'package:anchor/core/widgets/gradient_background.dart';
import 'package:anchor/core/widgets/quill_preview.dart';
import 'package:anchor/features/notes/domain/note.dart';
import 'package:anchor/features/notes/presentation/widgets/note_card.dart';
import 'package:anchor/features/notes/presentation/widgets/notes_search_bar.dart';
import 'package:anchor/features/sync/presentation/sync_warning.dart';

/// A titled, back-navigable, searchable list of [NoteCard]s with per-row
/// actions, and, given [selectionActions], notes to pick by a long press.
class NoteListPage extends StatefulWidget {
  const NoteListPage({
    super.key,
    required this.title,
    required this.notes,
    required this.emptyIcon,
    required this.emptyMessage,
    required this.datePrefix,
    required this.trailingActions,
    this.actions,
    this.selectionActions,
    this.hidesInvisible = false,
  });

  final String title;
  final AsyncValue<List<Note>> notes;
  final IconData emptyIcon;
  final String emptyMessage;

  /// Prefix for the timestamp on each card, e.g. 'Archived'.
  final String datePrefix;

  /// Row actions for a given note, shown at the trailing edge of its card.
  final List<Widget> Function(Note note) trailingActions;

  /// App bar actions.
  final List<Widget>? actions;

  /// App bar actions for the picked notes; [done] leaves selection once one
  /// has done its work. Without it, notes can't be picked.
  final List<Widget> Function(List<Note> selected, VoidCallback done)?
  selectionActions;

  /// Leaves out invisible notes until something is searched for.
  final bool hidesInvisible;

  @override
  State<NoteListPage> createState() => _NoteListPageState();
}

class _NoteListPageState extends State<NoteListPage> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _selecting = false;
  Set<String> _selected = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggle(String id) => setState(() {
    _selecting = true;
    _selected = Set.of(_selected);
    if (!_selected.remove(id)) _selected.add(id);
  });

  void _exitSelection() {
    // Also called once an action is done, when the page may be gone.
    if (!mounted) return;
    setState(() {
      _selecting = false;
      _selected = {};
    });
  }

  List<Widget> _selectionBarActions(List<Note> shown) {
    // Notes that went away (unarchived elsewhere, say) drop out.
    final picked = [
      for (final note in widget.notes.value ?? const <Note>[])
        if (_selected.contains(note.id)) note,
    ];
    final allPicked =
        shown.isNotEmpty && shown.every((n) => _selected.contains(n.id));
    return [
      if (picked.isNotEmpty)
        ...widget.selectionActions!(picked, _exitSelection),
      IconButton(
        icon: Icon(allPicked ? LucideIcons.checkSquare : LucideIcons.square),
        onPressed: () => setState(
          () => _selected = allPicked ? {} : {for (final n in shown) n.id},
        ),
        tooltip: allPicked ? 'Deselect all' : 'Select all',
      ),
    ];
  }

  bool _matches(Note note) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return !(widget.hidesInvisible && note.isInvisible);
    return note.title.toLowerCase().contains(q) ||
        extractPlainTextFromQuillContent(
          note.content,
        ).toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final shownNotes = (widget.notes.value ?? const <Note>[])
        .where(_matches)
        .toList();
    final count = _selected.length;
    return PopScope(
      // Back steps out of selection first.
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exitSelection();
      },
      child: AppPageScaffold(
        title: Text(
          !_selecting
              ? widget.title
              : count == 0
              ? 'Select notes'
              : '$count ${count == 1 ? 'note' : 'notes'}',
        ),
        leading: _selecting
            ? IconButton(
                icon: const Icon(LucideIcons.x),
                onPressed: _exitSelection,
                tooltip: 'Cancel selection',
              )
            : null,
        actions: _selecting ? _selectionBarActions(shownNotes) : widget.actions,
        wash: PageWash.content,
        body: widget.notes.when(
          data: (notes) {
            if (notes.isEmpty) {
              return AppEmptyState(
                icon: widget.emptyIcon,
                message: widget.emptyMessage,
              );
            }
            final dims = context.dims;
            final shown = notes.where(_matches).toList();
            return ListView.builder(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: dims.screenInsets.copyWith(
                top: AppPageScaffold.topInset(context) + dims.screenGutter,
              ),
              itemCount: shown.length + 2,
              findChildIndexCallback: (key) {
                final index = shown.indexWhere((n) => ValueKey(n.id) == key);
                return index < 0 ? null : index + 2;
              },
              // Each card has its own; around it, one would keep the card
              // from seeing it moved, to strike into place (see Strike).
              addRepaintBoundaries: false,
              itemBuilder: (context, index) {
                if (index == 0) return const SyncWarning();
                if (index == 1) {
                  return Padding(
                    padding: EdgeInsets.only(bottom: dims.listItemSpacing),
                    child: Column(
                      children: [
                        NotesSearchBar(
                          controller: _searchController,
                          query: _query,
                          onChanged: (value) => setState(() => _query = value),
                          onClear: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        ),
                        if (shown.isEmpty)
                          Padding(
                            padding: EdgeInsets.only(top: dims.xl),
                            child: Text(
                              'No matching notes found',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                      ],
                    ),
                  );
                }
                final note = shown[index - 2];
                return Padding(
                  // Keyed by note, so the cards after a deleted one move up
                  // instead of taking on the notes after theirs.
                  key: ValueKey(note.id),
                  padding: EdgeInsets.only(bottom: dims.listItemSpacing),
                  child: NoteCard(
                    note: note,
                    datePrefix: widget.datePrefix,
                    isSelectionMode: _selecting,
                    isSelected: _selected.contains(note.id),
                    onLongPress: widget.selectionActions == null
                        ? null
                        : () => _toggle(note.id),
                    onTap: _selecting
                        ? () => _toggle(note.id)
                        : () => context.push(
                            Uri(
                              path: '/note/${note.id}',
                              queryParameters: _query.trim().isEmpty
                                  ? null
                                  : {'hl': _query.trim()},
                            ).toString(),
                            extra: note,
                          ),
                    trailingActions: _selecting
                        ? const []
                        : widget.trailingActions(note),
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: $err')),
        ),
      ),
    );
  }
}
