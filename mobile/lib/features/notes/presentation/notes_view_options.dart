import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:anchor/core/app_initializer.dart';
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

/// Where a note sorts in "Date modified, newest first", as on the web: by its
/// last edit, unless it was dragged (on the web) since, in which case where
/// it was put. Both are milliseconds, so dragged and edited notes mix.
double noteSortKey(Note note) {
  final edited = (note.updatedAt ?? DateTime(0)).millisecondsSinceEpoch
      .toDouble();
  final position = note.position;
  final positionedAt = note.positionedAt;
  if (position == null || positionedAt == null) return edited;
  return positionedAt.millisecondsSinceEpoch >= edited ? position : edited;
}

/// Where [note] sorts now, to keep it there rather than move it up when
/// it's changed from its card. A hair off its current place, so the server,
/// which only stamps a place that changed, records it as placed after the
/// change.
double keptPlace(Note note) => noteSortKey(note) - 0.01;

/// The place for a note dropped between [above] and [below] (either may be
/// missing at the ends), in [noteSortKey] terms.
double positionBetween(Note? above, Note? below) {
  const step = 1000.0;
  if (above != null && below != null) {
    return (noteSortKey(above) + noteSortKey(below)) / 2;
  }
  if (above != null) return noteSortKey(above) - step;
  if (below != null) return noteSortKey(below) + step;
  return DateTime.now().millisecondsSinceEpoch.toDouble();
}

/// Pinned notes stay on top, then the chosen sort, then the id.
int Function(Note, Note) noteComparator(NotesViewOptions options) {
  return (a, b) {
    if (a.isPinned != b.isPinned) {
      return a.isPinned ? -1 : 1;
    }

    final int compare = switch (options.sortOption) {
      // Newest first takes dragged places into account; oldest first is the
      // plain edit time.
      SortOption.dateModified =>
        options.isAscending
            ? (a.updatedAt ?? DateTime(0)).compareTo(b.updatedAt ?? DateTime(0))
            : noteSortKey(a).compareTo(noteSortKey(b)),
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

  /// Whether the options read at launch were used already; later builds
  /// read storage, which has any changes since.
  static bool _tookStartupValues = false;

  @override
  FutureOr<NotesViewOptions> build() {
    // The first time, straight from what was read at launch, so the list
    // shows with the app's first frame instead of after four more reads.
    if (!_tookStartupValues && startupStorage.isNotEmpty) {
      _tookStartupValues = true;
      return _optionsFrom((key) => startupStorage[key]);
    }
    return _loadOptions();
  }

  Future<NotesViewOptions> _loadOptions() async {
    try {
      final values = <String, String?>{
        for (final key in [
          _keyViewType,
          _keySortOption,
          _keyIsAscending,
          _keyShowPictures,
        ])
          key: await _storage.read(key: key),
      };
      return _optionsFrom((key) => values[key]);
    } catch (e) {
      return const NotesViewOptions();
    }
  }

  NotesViewOptions _optionsFrom(String? Function(String key) read) {
    final viewTypeStr = read(_keyViewType);
    final sortOptionStr = read(_keySortOption);
    final isAscendingStr = read(_keyIsAscending);
    final showPicturesStr = read(_keyShowPictures);

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
