// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'note_history_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// A note's versions kept on this phone, newest first.

@ProviderFor(noteRevisions)
final noteRevisionsProvider = NoteRevisionsFamily._();

/// A note's versions kept on this phone, newest first.

final class NoteRevisionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<NoteRevision>>,
          List<NoteRevision>,
          Stream<List<NoteRevision>>
        >
    with
        $FutureModifier<List<NoteRevision>>,
        $StreamProvider<List<NoteRevision>> {
  /// A note's versions kept on this phone, newest first.
  NoteRevisionsProvider._({
    required NoteRevisionsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'noteRevisionsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$noteRevisionsHash();

  @override
  String toString() {
    return r'noteRevisionsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<NoteRevision>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<NoteRevision>> create(Ref ref) {
    final argument = this.argument as String;
    return noteRevisions(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is NoteRevisionsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$noteRevisionsHash() => r'd03e542665c69004c0e86ae5e4d96f75488add9d';

/// A note's versions kept on this phone, newest first.

final class NoteRevisionsFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<NoteRevision>>, String> {
  NoteRevisionsFamily._()
    : super(
        retry: null,
        name: r'noteRevisionsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// A note's versions kept on this phone, newest first.

  NoteRevisionsProvider call(String noteId) =>
      NoteRevisionsProvider._(argument: noteId, from: this);

  @override
  String toString() => r'noteRevisionsProvider';
}

@ProviderFor(noteHistoryPosition)
final noteHistoryPositionProvider = NoteHistoryPositionFamily._();

final class NoteHistoryPositionProvider
    extends
        $FunctionalProvider<
          AsyncValue<NoteHistoryPosition>,
          NoteHistoryPosition,
          Stream<NoteHistoryPosition>
        >
    with
        $FutureModifier<NoteHistoryPosition>,
        $StreamProvider<NoteHistoryPosition> {
  NoteHistoryPositionProvider._({
    required NoteHistoryPositionFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'noteHistoryPositionProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$noteHistoryPositionHash();

  @override
  String toString() {
    return r'noteHistoryPositionProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<NoteHistoryPosition> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<NoteHistoryPosition> create(Ref ref) {
    final argument = this.argument as String;
    return noteHistoryPosition(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is NoteHistoryPositionProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$noteHistoryPositionHash() =>
    r'4e6067925f1eef3122be6c0d701b348b6f50c275';

final class NoteHistoryPositionFamily extends $Family
    with $FunctionalFamilyOverride<Stream<NoteHistoryPosition>, String> {
  NoteHistoryPositionFamily._()
    : super(
        retry: null,
        name: r'noteHistoryPositionProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  NoteHistoryPositionProvider call(String noteId) =>
      NoteHistoryPositionProvider._(argument: noteId, from: this);

  @override
  String toString() => r'noteHistoryPositionProvider';
}

@ProviderFor(versionChanges)
final versionChangesProvider = VersionChangesFamily._();

final class VersionChangesProvider
    extends $FunctionalProvider<VersionChanges, VersionChanges, VersionChanges>
    with $Provider<VersionChanges> {
  VersionChangesProvider._({
    required VersionChangesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'versionChangesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$versionChangesHash();

  @override
  String toString() {
    return r'versionChangesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<VersionChanges> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  VersionChanges create(Ref ref) {
    final argument = this.argument as String;
    return versionChanges(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VersionChanges value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VersionChanges>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is VersionChangesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$versionChangesHash() => r'5b23414288bd816404e95ca9ae6fd77a9ab44354';

final class VersionChangesFamily extends $Family
    with $FunctionalFamilyOverride<VersionChanges, String> {
  VersionChangesFamily._()
    : super(
        retry: null,
        name: r'versionChangesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  VersionChangesProvider call(String noteId) =>
      VersionChangesProvider._(argument: noteId, from: this);

  @override
  String toString() => r'versionChangesProvider';
}
