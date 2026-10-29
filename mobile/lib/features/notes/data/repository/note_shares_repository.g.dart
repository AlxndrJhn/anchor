// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'note_shares_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(noteSharesRepository)
final noteSharesRepositoryProvider = NoteSharesRepositoryProvider._();

final class NoteSharesRepositoryProvider
    extends
        $FunctionalProvider<
          NoteSharesRepository,
          NoteSharesRepository,
          NoteSharesRepository
        >
    with $Provider<NoteSharesRepository> {
  NoteSharesRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'noteSharesRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$noteSharesRepositoryHash();

  @$internal
  @override
  $ProviderElement<NoteSharesRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  NoteSharesRepository create(Ref ref) {
    return noteSharesRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NoteSharesRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NoteSharesRepository>(value),
    );
  }
}

String _$noteSharesRepositoryHash() =>
    r'4b5b6424ef9b5a917e20bcb2e561aafb1959e288';
