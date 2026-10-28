// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'note_freeze_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(noteFreezeRepository)
final noteFreezeRepositoryProvider = NoteFreezeRepositoryProvider._();

final class NoteFreezeRepositoryProvider
    extends
        $FunctionalProvider<
          NoteFreezeRepository,
          NoteFreezeRepository,
          NoteFreezeRepository
        >
    with $Provider<NoteFreezeRepository> {
  NoteFreezeRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'noteFreezeRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$noteFreezeRepositoryHash();

  @$internal
  @override
  $ProviderElement<NoteFreezeRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  NoteFreezeRepository create(Ref ref) {
    return noteFreezeRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NoteFreezeRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NoteFreezeRepository>(value),
    );
  }
}

String _$noteFreezeRepositoryHash() =>
    r'c6cd1ccca88b03dc66e5c0783baa065a794cb997';
