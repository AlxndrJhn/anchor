// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'picture_aspect_ratios.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(pictureAspectRatios)
final pictureAspectRatiosProvider = PictureAspectRatiosProvider._();

final class PictureAspectRatiosProvider
    extends
        $FunctionalProvider<
          PictureAspectRatios,
          PictureAspectRatios,
          PictureAspectRatios
        >
    with $Provider<PictureAspectRatios> {
  PictureAspectRatiosProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pictureAspectRatiosProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pictureAspectRatiosHash();

  @$internal
  @override
  $ProviderElement<PictureAspectRatios> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PictureAspectRatios create(Ref ref) {
    return pictureAspectRatios(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PictureAspectRatios value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PictureAspectRatios>(value),
    );
  }
}

String _$pictureAspectRatiosHash() =>
    r'ac11e1f27bc01cf47af38e823078e8a920ab2de1';
