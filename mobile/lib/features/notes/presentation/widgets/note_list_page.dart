import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
/// actions.
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

  @override
  State<NoteListPage> createState() => _NoteListPageState();
}

class _NoteListPageState extends State<NoteListPage> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matches(Note note) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return note.title.toLowerCase().contains(q) ||
        extractPlainTextFromQuillContent(
          note.content,
        ).toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: Text(widget.title),
      actions: widget.actions,
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
            // Each card has its own; around it, one would keep the card from
            // seeing it moved, to strike into place (see Strike).
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
                  onTap: () => context.push(
                    Uri(
                      path: '/note/${note.id}',
                      queryParameters: _query.trim().isEmpty
                          ? null
                          : {'hl': _query.trim()},
                    ).toString(),
                    extra: note,
                  ),
                  trailingActions: widget.trailingActions(note),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
