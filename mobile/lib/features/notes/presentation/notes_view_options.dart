import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/logging/log_tags.dart';
import '../../../core/storage/preferences_repository.dart';
import '../domain/note.dart';

/// Saved as 'grid' (masonry) and 'uniform' (grid); stored options use these.
enum ViewType { masonry, grid, list }

enum SortOption { dateModified, title }

class NotesViewOptions {
  final ViewType viewType;
  final SortOption sortOption;
  final bool isAscending;

  /// A note's pictures on its card.
  final bool showPictures;

  const NotesViewOptions({
    this.viewType = ViewType.masonry,
    this.sortOption = SortOption.dateModified,
    this.isAscending = false,
    this.showPictures = true,
  });

  NotesViewOptions copyWith({
    ViewType? viewType,
    SortOption? sortOption,
    bool? isAscending,
    bool? showPictures,
  }) {
    return NotesViewOptions(
      viewType: viewType ?? this.viewType,
      sortOption: sortOption ?? this.sortOption,
      isAscending: isAscending ?? this.isAscending,
      showPictures: showPictures ?? this.showPictures,
    );
  }
}

int Function(Note, Note) noteComparator(NotesViewOptions options) {
  return (a, b) {
    if (a.isPinned != b.isPinned) {
      return a.isPinned ? -1 : 1;
    }

    final int compare = switch (options.sortOption) {
      SortOption.dateModified => (a.updatedAt ?? DateTime(0)).compareTo(
        b.updatedAt ?? DateTime(0),
      ),
      SortOption.title => a.title.trim().toLowerCase().compareTo(
        b.title.trim().toLowerCase(),
      ),
    };

    final ordered = options.isAscending ? compare : -compare;
    return ordered != 0 ? ordered : b.id.compareTo(a.id);
  };
}

class NotesViewOptionsNotifier extends AsyncNotifier<NotesViewOptions> {
  @override
  Future<NotesViewOptions> build() async {
    return _loadOptions();
  }

  Future<NotesViewOptions> _loadOptions() async {
    try {
      final preferences = ref.read(preferencesRepositoryProvider);
      final viewTypeStr = await preferences.getNotesViewType();
      final sortOptionStr = await preferences.getNotesSortOption();
      final isAscending = await preferences.getNotesSortAscending();
      final showPictures = await preferences.getNotesShowPictures();

      final viewType = switch (viewTypeStr) {
        'list' => ViewType.list,
        'uniform' => ViewType.grid,
        _ => ViewType.masonry,
      };

      final sortOption = sortOptionStr == 'title'
          ? SortOption.title
          : SortOption.dateModified;

      return NotesViewOptions(
        viewType: viewType,
        sortOption: sortOption,
        isAscending: isAscending,
        showPictures: showPictures,
      );
    } catch (error) {
      AppLogger.instance.warn(
        LogTags.settings,
        'Reading the view options failed',
        error: error,
      );
      return const NotesViewOptions();
    }
  }

  Future<void> _saveOptions(NotesViewOptions options) async {
    try {
      final preferences = ref.read(preferencesRepositoryProvider);
      await preferences.setNotesViewType(switch (options.viewType) {
        ViewType.list => 'list',
        ViewType.grid => 'uniform',
        ViewType.masonry => 'grid',
      });
      await preferences.setNotesSortOption(
        options.sortOption == SortOption.title ? 'title' : 'dateModified',
      );
      await preferences.setNotesSortAscending(options.isAscending);
      await preferences.setNotesShowPictures(options.showPictures);
    } catch (error) {
      AppLogger.instance.warn(
        LogTags.settings,
        'Saving the view options failed',
        error: error,
      );
    }
  }

  Future<void> setViewType(ViewType viewType) =>
      _update((options) => options.copyWith(viewType: viewType));

  Future<void> setSort(SortOption sortOption, {required bool isAscending}) =>
      _update(
        (options) =>
            options.copyWith(sortOption: sortOption, isAscending: isAscending),
      );

  Future<void> setSortDirection(bool isAscending) =>
      _update((options) => options.copyWith(isAscending: isAscending));

  Future<void> setShowPictures(bool showPictures) =>
      _update((options) => options.copyWith(showPictures: showPictures));

  Future<void> _update(
    NotesViewOptions Function(NotesViewOptions options) change,
  ) async {
    final options = change(state.value ?? const NotesViewOptions());
    state = AsyncData(options);
    await _saveOptions(options);
  }
}

final notesViewOptionsProvider =
    AsyncNotifierProvider<NotesViewOptionsNotifier, NotesViewOptions>(
      NotesViewOptionsNotifier.new,
    );
