// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'note_history_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(noteHistoryRepository)
final noteHistoryRepositoryProvider = NoteHistoryRepositoryProvider._();

final class NoteHistoryRepositoryProvider
    extends
        $FunctionalProvider<
          NoteHistoryRepository,
          NoteHistoryRepository,
          NoteHistoryRepository
        >
    with $Provider<NoteHistoryRepository> {
  NoteHistoryRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'noteHistoryRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$noteHistoryRepositoryHash();

  @$internal
  @override
  $ProviderElement<NoteHistoryRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  NoteHistoryRepository create(Ref ref) {
    return noteHistoryRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NoteHistoryRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NoteHistoryRepository>(value),
    );
  }
}

String _$noteHistoryRepositoryHash() =>
    r'dfb52326cfc2446002e3257095119cc4931deecd';
