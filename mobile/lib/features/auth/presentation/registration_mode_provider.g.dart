// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'registration_mode_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(registrationMode)
final registrationModeProvider = RegistrationModeProvider._();

final class RegistrationModeProvider
    extends
        $FunctionalProvider<
          AsyncValue<RegistrationMode>,
          RegistrationMode,
          FutureOr<RegistrationMode>
        >
    with $FutureModifier<RegistrationMode>, $FutureProvider<RegistrationMode> {
  RegistrationModeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'registrationModeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$registrationModeHash();

  @$internal
  @override
  $FutureProviderElement<RegistrationMode> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<RegistrationMode> create(Ref ref) {
    return registrationMode(ref);
  }
}

String _$registrationModeHash() => r'8cdc996c6a72284cc1f44713d3bbcad710a226f3';
