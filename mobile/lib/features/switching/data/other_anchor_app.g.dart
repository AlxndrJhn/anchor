// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'other_anchor_app.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The other Anchor app, looked for again whenever this one comes back to
/// the front, so the server page's note goes once it's uninstalled.

@ProviderFor(OtherAnchorAppController)
final otherAnchorAppControllerProvider = OtherAnchorAppControllerProvider._();

/// The other Anchor app, looked for again whenever this one comes back to
/// the front, so the server page's note goes once it's uninstalled.
final class OtherAnchorAppControllerProvider
    extends $AsyncNotifierProvider<OtherAnchorAppController, OtherAnchorApp?> {
  /// The other Anchor app, looked for again whenever this one comes back to
  /// the front, so the server page's note goes once it's uninstalled.
  OtherAnchorAppControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'otherAnchorAppControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$otherAnchorAppControllerHash();

  @$internal
  @override
  OtherAnchorAppController create() => OtherAnchorAppController();
}

String _$otherAnchorAppControllerHash() =>
    r'6a07e0eb6a01c6ffa790cd803479df858767c3e0';

/// The other Anchor app, looked for again whenever this one comes back to
/// the front, so the server page's note goes once it's uninstalled.

abstract class _$OtherAnchorAppController
    extends $AsyncNotifier<OtherAnchorApp?> {
  FutureOr<OtherAnchorApp?> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<OtherAnchorApp?>, OtherAnchorApp?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<OtherAnchorApp?>, OtherAnchorApp?>,
              AsyncValue<OtherAnchorApp?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
