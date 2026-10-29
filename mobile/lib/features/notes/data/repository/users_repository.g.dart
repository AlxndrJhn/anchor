// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'users_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(usersRepository)
final usersRepositoryProvider = UsersRepositoryProvider._();

final class UsersRepositoryProvider
    extends
        $FunctionalProvider<UsersRepository, UsersRepository, UsersRepository>
    with $Provider<UsersRepository> {
  UsersRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'usersRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$usersRepositoryHash();

  @$internal
  @override
  $ProviderElement<UsersRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  UsersRepository create(Ref ref) {
    return usersRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UsersRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UsersRepository>(value),
    );
  }
}

String _$usersRepositoryHash() => r'a55e74e8f71fbd6a7e186fd146debe22a5589521';
