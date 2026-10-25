// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'note_copies_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(noteCopiesRepository)
final noteCopiesRepositoryProvider = NoteCopiesRepositoryProvider._();

final class NoteCopiesRepositoryProvider
    extends
        $FunctionalProvider<
          NoteCopiesRepository,
          NoteCopiesRepository,
          NoteCopiesRepository
        >
    with $Provider<NoteCopiesRepository> {
  NoteCopiesRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'noteCopiesRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$noteCopiesRepositoryHash();

  @$internal
  @override
  $ProviderElement<NoteCopiesRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  NoteCopiesRepository create(Ref ref) {
    return noteCopiesRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NoteCopiesRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NoteCopiesRepository>(value),
    );
  }
}

String _$noteCopiesRepositoryHash() =>
    r'067727b84092eec59833a36373ab7f9c229fd376';
