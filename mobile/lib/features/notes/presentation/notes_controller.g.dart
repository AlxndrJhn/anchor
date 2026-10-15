// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notes_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The notes in Notes, filtered by the selected tag.

@ProviderFor(notes)
final notesProvider = NotesProvider._();

/// The notes in Notes, filtered by the selected tag.

final class NotesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Note>>,
          List<Note>,
          Stream<List<Note>>
        >
    with $FutureModifier<List<Note>>, $StreamProvider<List<Note>> {
  /// The notes in Notes, filtered by the selected tag.
  NotesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notesHash();

  @$internal
  @override
  $StreamProviderElement<List<Note>> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<List<Note>> create(Ref ref) {
    return notes(ref);
  }
}

String _$notesHash() => r'fe5da065cba4748b9e17f2afd91ad96758e2f2aa';

/// Null once the note is gone.

@ProviderFor(note)
final noteProvider = NoteFamily._();

/// Null once the note is gone.

final class NoteProvider
    extends $FunctionalProvider<AsyncValue<Note?>, Note?, Stream<Note?>>
    with $FutureModifier<Note?>, $StreamProvider<Note?> {
  /// Null once the note is gone.
  NoteProvider._({
    required NoteFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'noteProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$noteHash();

  @override
  String toString() {
    return r'noteProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<Note?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<Note?> create(Ref ref) {
    final argument = this.argument as String;
    return note(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is NoteProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$noteHash() => r'5ca14d0c797b5b4e5667c2e1790172c094a5f9d1';

/// Null once the note is gone.

final class NoteFamily extends $Family
    with $FunctionalFamilyOverride<Stream<Note?>, String> {
  NoteFamily._()
    : super(
        retry: null,
        name: r'noteProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Null once the note is gone.

  NoteProvider call(String id) => NoteProvider._(argument: id, from: this);

  @override
  String toString() => r'noteProvider';
}

@ProviderFor(archivedNotes)
final archivedNotesProvider = ArchivedNotesProvider._();

final class ArchivedNotesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Note>>,
          List<Note>,
          Stream<List<Note>>
        >
    with $FutureModifier<List<Note>>, $StreamProvider<List<Note>> {
  ArchivedNotesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'archivedNotesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$archivedNotesHash();

  @$internal
  @override
  $StreamProviderElement<List<Note>> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<List<Note>> create(Ref ref) {
    return archivedNotes(ref);
  }
}

String _$archivedNotesHash() => r'5e6f9f70f06d129b3ffd305b1a5b9adf859e3054';

@ProviderFor(trashedNotes)
final trashedNotesProvider = TrashedNotesProvider._();

final class TrashedNotesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Note>>,
          List<Note>,
          Stream<List<Note>>
        >
    with $FutureModifier<List<Note>>, $StreamProvider<List<Note>> {
  TrashedNotesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'trashedNotesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$trashedNotesHash();

  @$internal
  @override
  $StreamProviderElement<List<Note>> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<List<Note>> create(Ref ref) {
    return trashedNotes(ref);
  }
}

String _$trashedNotesHash() => r'd9c55f79aecb67d2e4dcf6ba63d8709f9f5cb0e1';

@ProviderFor(SearchQuery)
final searchQueryProvider = SearchQueryProvider._();

final class SearchQueryProvider extends $NotifierProvider<SearchQuery, String> {
  SearchQueryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'searchQueryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$searchQueryHash();

  @$internal
  @override
  SearchQuery create() => SearchQuery();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$searchQueryHash() => r'99ff8829a2de8a3351c2c5a931316b171cd121ee';

abstract class _$SearchQuery extends $Notifier<String> {
  String build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<String, String>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String, String>,
              String,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(SelectionMode)
final selectionModeProvider = SelectionModeProvider._();

final class SelectionModeProvider
    extends $NotifierProvider<SelectionMode, bool> {
  SelectionModeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'selectionModeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$selectionModeHash();

  @$internal
  @override
  SelectionMode create() => SelectionMode();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$selectionModeHash() => r'7c4ef78c428243bcf513370860e626143a8c75b4';

abstract class _$SelectionMode extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(SelectedNoteIds)
final selectedNoteIdsProvider = SelectedNoteIdsProvider._();

final class SelectedNoteIdsProvider
    extends $NotifierProvider<SelectedNoteIds, Set<String>> {
  SelectedNoteIdsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'selectedNoteIdsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$selectedNoteIdsHash();

  @$internal
  @override
  SelectedNoteIds create() => SelectedNoteIds();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Set<String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Set<String>>(value),
    );
  }
}

String _$selectedNoteIdsHash() => r'c1bfd8f8f1fc2dba57166015e8d4d82b0e8992a9';

abstract class _$SelectedNoteIds extends $Notifier<Set<String>> {
  Set<String> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<Set<String>, Set<String>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Set<String>, Set<String>>,
              Set<String>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(unsyncedNoteCount)
final unsyncedNoteCountProvider = UnsyncedNoteCountProvider._();

final class UnsyncedNoteCountProvider extends $FunctionalProvider<int, int, int>
    with $Provider<int> {
  UnsyncedNoteCountProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'unsyncedNoteCountProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$unsyncedNoteCountHash();

  @$internal
  @override
  $ProviderElement<int> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  int create(Ref ref) {
    return unsyncedNoteCount(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$unsyncedNoteCountHash() => r'a6b9b4b4c2ffb9931870957e4ade337f27b4d8cb';

/// Every note in Notes, whatever tag the list is filtered by.

@ProviderFor(allActiveNotes)
final allActiveNotesProvider = AllActiveNotesProvider._();

/// Every note in Notes, whatever tag the list is filtered by.

final class AllActiveNotesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Note>>,
          List<Note>,
          Stream<List<Note>>
        >
    with $FutureModifier<List<Note>>, $StreamProvider<List<Note>> {
  /// Every note in Notes, whatever tag the list is filtered by.
  AllActiveNotesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'allActiveNotesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$allActiveNotesHash();

  @$internal
  @override
  $StreamProviderElement<List<Note>> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<List<Note>> create(Ref ref) {
    return allActiveNotes(ref);
  }
}

String _$allActiveNotesHash() => r'36a8fc752bc672cb7b7879b9a74079f997ed0d4c';
