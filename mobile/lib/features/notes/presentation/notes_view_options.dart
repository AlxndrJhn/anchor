import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:anchor/features/notes/domain/note.dart';

enum ViewType { grid, list }

enum SortOption { dateModified, title }

class NotesViewOptions {
  final ViewType viewType;
  final SortOption sortOption;
  final bool isAscending;

  /// Pictures across the top of note cards.
  final bool showPictures;

  const NotesViewOptions({
    this.viewType = ViewType.grid,
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

/// Pinned notes stay on top, then the chosen sort, then the id.
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
  static const _storage = FlutterSecureStorage();
  static const _keyViewType = 'notes_view_type';
  static const _keySortOption = 'notes_sort_option';
  static const _keyIsAscending = 'notes_is_ascending';
  static const _keyShowPictures = 'notes_show_pictures';

  @override
  Future<NotesViewOptions> build() async {
    return _loadOptions();
  }

  Future<NotesViewOptions> _loadOptions() async {
    try {
      final viewTypeStr = await _storage.read(key: _keyViewType);
      final sortOptionStr = await _storage.read(key: _keySortOption);
      final isAscendingStr = await _storage.read(key: _keyIsAscending);
      final showPicturesStr = await _storage.read(key: _keyShowPictures);

      final viewType = viewTypeStr == 'list' ? ViewType.list : ViewType.grid;

      final sortOption = sortOptionStr == 'title'
          ? SortOption.title
          : SortOption.dateModified;

      final isAscending = isAscendingStr == 'true';

      return NotesViewOptions(
        viewType: viewType,
        sortOption: sortOption,
        isAscending: isAscending,
        showPictures: showPicturesStr != 'false',
      );
    } catch (e) {
      return const NotesViewOptions();
    }
  }

  Future<void> _saveOptions(NotesViewOptions options) async {
    try {
      await _storage.write(
        key: _keyViewType,
        value: options.viewType == ViewType.list ? 'list' : 'grid',
      );
      await _storage.write(
        key: _keySortOption,
        value: options.sortOption == SortOption.title
            ? 'title'
            : 'dateModified',
      );
      await _storage.write(
        key: _keyIsAscending,
        value: options.isAscending.toString(),
      );
      await _storage.write(
        key: _keyShowPictures,
        value: options.showPictures.toString(),
      );
    } catch (e) {
      // Ignore storage errors
    }
  }

  Future<void> setViewType(ViewType viewType) async {
    final current = state.value ?? const NotesViewOptions();
    final newOptions = current.copyWith(viewType: viewType);
    state = AsyncData(newOptions);
    await _saveOptions(newOptions);
  }

  Future<void> setSortOption(SortOption sortOption) async {
    final current = state.value ?? const NotesViewOptions();
    final newOptions = current.copyWith(sortOption: sortOption);
    state = AsyncData(newOptions);
    await _saveOptions(newOptions);
  }

  Future<void> toggleSortDirection() async {
    final current = state.value ?? const NotesViewOptions();
    final newOptions = current.copyWith(isAscending: !current.isAscending);
    state = AsyncData(newOptions);
    await _saveOptions(newOptions);
  }

  Future<void> setShowPictures(bool showPictures) async {
    final current = state.value ?? const NotesViewOptions();
    final newOptions = current.copyWith(showPictures: showPictures);
    state = AsyncData(newOptions);
    await _saveOptions(newOptions);
  }

  Future<void> setSortDirection(bool isAscending) async {
    final current = state.value ?? const NotesViewOptions();
    final newOptions = current.copyWith(isAscending: isAscending);
    state = AsyncData(newOptions);
    await _saveOptions(newOptions);
  }
}

final notesViewOptionsProvider =
    AsyncNotifierProvider<NotesViewOptionsNotifier, NotesViewOptions>(
      NotesViewOptionsNotifier.new,
    );
