import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/app_bootstrap.dart';
import '../../../core/motion/haptics.dart';
import '../../../core/storage/preferences_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../../reminders/data/reminder_permissions.dart';
import '../../tags/presentation/tags_controller.dart';
import '../domain/note.dart';
import '../domain/note_blocks.dart';
import 'note_folder.dart';
import 'notes_controller.dart';
import 'notes_view_options.dart';

part 'notes_list_controller.g.dart';

enum NoteGroupKind { all, pinned, others, archived }

class NoteGroup {
  const NoteGroup(
    this.kind,
    this.notes, {
    this.isFolded = false,
    this.canFold = false,
  });

  final NoteGroupKind kind;
  final List<Note> notes;
  final bool isFolded;
  final bool canFold;

  bool get isPinned => kind == NoteGroupKind.pinned;
  bool get isArchived => kind == NoteGroupKind.archived;

  String? labelIn(AppLocalizations l10n) => switch (kind) {
    NoteGroupKind.all => null,
    NoteGroupKind.pinned => l10n.groupPinned,
    NoteGroupKind.others => l10n.groupOthers,
    NoteGroupKind.archived => l10n.groupArchived,
  };
}

class VisibleNotes {
  const VisibleNotes({
    required this.notes,
    required this.groups,
    required this.isLoaded,
    this.listsArchived = false,
    this.isArchivedOpen = false,
  });

  /// Folded notes are left out.
  final List<Note> notes;
  final List<NoteGroup> groups;

  final bool isLoaded;

  /// In a search or on a tag's page, archived notes follow the others.
  final bool listsArchived;
  final bool isArchivedOpen;

  bool showsArchived({required bool hasOtherNotes}) =>
      listsArchived &&
      !_isArchivedFolded(isOpen: isArchivedOpen, hasOtherNotes: hasOtherNotes);
}

bool _isArchivedFolded({required bool isOpen, required bool hasOtherNotes}) =>
    hasOtherNotes && !isOpen;

@riverpod
VisibleNotes visibleNotes(Ref ref) {
  final folder = ref.watch(noteFolderProvider);
  final source = switch (folder) {
    NoteFolder.notes => ref.watch(notesProvider),
    NoteFolder.archive => ref.watch(archivedNotesProvider),
    NoteFolder.trash => ref.watch(trashedNotesProvider),
  };
  final query = ref.watch(searchQueryProvider);
  final options =
      ref.watch(notesViewOptionsProvider).value ?? const NotesViewOptions();
  final notes = source.value ?? const <Note>[];

  final words = query.trim().toLowerCase();
  final searchText = ref.watch(noteSearchTextProvider);
  bool matches(Note note) =>
      words.isEmpty ||
      note.title.toLowerCase().contains(words) ||
      searchText.of(note).contains(words);
  final comparator = noteComparator(options);
  final visible = [
    for (final note in notes)
      if (matches(note)) note,
  ]..sort(comparator);
  final groups = folder == NoteFolder.notes && query.isEmpty
      ? _pinnedFirst(visible)
      : [NoteGroup(NoteGroupKind.all, visible)];

  final tagId = folder == NoteFolder.notes
      ? ref.watch(selectedTagFilterProvider)
      : null;
  final isSearching = words.isNotEmpty;
  if (folder != NoteFolder.notes || (!isSearching && tagId == null)) {
    return VisibleNotes(
      notes: visible,
      groups: groups,
      isLoaded: source.hasValue,
    );
  }

  final archivedSource = ref.watch(archivedNotesProvider);
  final archived = [
    for (final note in archivedSource.value ?? const <Note>[])
      if ((tagId == null || note.tagIds.contains(tagId)) && matches(note)) note,
  ]..sort(comparator);
  final isOpen =
      isSearching || ref.watch(openArchivedTagsProvider).contains(tagId);
  final isFolded = _isArchivedFolded(
    isOpen: isOpen,
    hasOtherNotes: visible.isNotEmpty,
  );
  return VisibleNotes(
    notes: [...visible, if (!isFolded) ...archived],
    groups: [
      for (final group in groups)
        if (group.notes.isNotEmpty) group,
      if (archived.isNotEmpty)
        NoteGroup(
          NoteGroupKind.archived,
          archived,
          isFolded: isFolded,
          canFold: !isSearching && visible.isNotEmpty,
        ),
    ],
    isLoaded: source.hasValue && archivedSource.hasValue,
    listsArchived: true,
    isArchivedOpen: isOpen,
  );
}

/// The tags whose page shows its archived notes.
@Riverpod(keepAlive: true)
class OpenArchivedTags extends _$OpenArchivedTags {
  @override
  Set<String> build() => {...ref.watch(appBootstrapProvider).openArchivedTags};

  Future<void> toggle(String tagId) async {
    final next = {...state};
    if (!next.remove(tagId)) next.add(tagId);
    state = next;
    await ref
        .read(preferencesRepositoryProvider)
        .setOpenArchivedTags(next.toList());
  }
}

List<NoteGroup> _pinnedFirst(List<Note> notes) {
  final pinned = notes.where((n) => n.isPinned).toList();
  final others = notes.where((n) => !n.isPinned).toList();
  if (pinned.isEmpty) return [NoteGroup(NoteGroupKind.all, others)];
  return [
    NoteGroup(NoteGroupKind.pinned, pinned),
    if (others.isNotEmpty) NoteGroup(NoteGroupKind.others, others),
  ];
}

/// Lower-cased note text for search, cached per content.
class NoteSearchText {
  final Map<String, ({String? content, String text})> _cache = {};

  String of(Note note) {
    final known = _cache[note.id];
    if (known != null && known.content == note.content) return known.text;
    final text = plainTextOf(note.content).toLowerCase();
    _cache[note.id] = (content: note.content, text: text);
    return text;
  }
}

@Riverpod(keepAlive: true)
NoteSearchText noteSearchText(Ref ref) => NoteSearchText();

@riverpod
bool shouldAskForReminderPermissions(Ref ref) {
  if (ref.watch(noteFolderProvider) != NoteFolder.notes) return false;
  final permissions = ref.watch(reminderPermissionsControllerProvider).value;
  if (permissions == null || permissions.canRingOnTime) return false;
  final notes = ref.watch(allActiveNotesProvider).value ?? const <Note>[];
  return notes.any((n) => n.hasReminder);
}

class NoteSelection {
  const NoteSelection(this.ref);

  final WidgetRef ref;

  void start(Note note) {
    Haptics.medium();
    FocusManager.instance.primaryFocus?.unfocus();
    ref.read(selectionModeProvider.notifier).setEnabled(true);
    ref.read(selectedNoteIdsProvider.notifier).add(note.id);
  }

  void toggle(Note note) {
    Haptics.selection();
    ref.read(selectedNoteIdsProvider.notifier).toggle(note.id);
  }

  void toggleAll(List<Note> showing) {
    Haptics.selection();
    final ids = ref.read(selectedNoteIdsProvider.notifier);
    final selected = ref.read(selectedNoteIdsProvider);
    if (showing.every((note) => selected.contains(note.id))) {
      ids.clear();
    } else {
      ids.selectAll([for (final n in showing) n.id]);
    }
  }

  void end() {
    ref.read(selectionModeProvider.notifier).setEnabled(false);
    ref.read(selectedNoteIdsProvider.notifier).clear();
  }
}
