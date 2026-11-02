// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'other_anchor_app.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The other Anchor app, looked for again whenever this one comes back to
/// the front, so uninstalling it takes its notices away.

@ProviderFor(OtherAnchorAppController)
final otherAnchorAppControllerProvider = OtherAnchorAppControllerProvider._();

/// The other Anchor app, looked for again whenever this one comes back to
/// the front, so uninstalling it takes its notices away.
final class OtherAnchorAppControllerProvider
    extends $AsyncNotifierProvider<OtherAnchorAppController, OtherAnchorApp?> {
  /// The other Anchor app, looked for again whenever this one comes back to
  /// the front, so uninstalling it takes its notices away.
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
/// the front, so uninstalling it takes its notices away.

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

/// Whether the user said they'd keep the other app, so the "you can
/// uninstall it" banner stays away.

@ProviderFor(OtherAppDismissed)
final otherAppDismissedProvider = OtherAppDismissedProvider._();

/// Whether the user said they'd keep the other app, so the "you can
/// uninstall it" banner stays away.
final class OtherAppDismissedProvider
    extends $AsyncNotifierProvider<OtherAppDismissed, bool> {
  /// Whether the user said they'd keep the other app, so the "you can
  /// uninstall it" banner stays away.
  OtherAppDismissedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'otherAppDismissedProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$otherAppDismissedHash();

  @$internal
  @override
  OtherAppDismissed create() => OtherAppDismissed();
}

String _$otherAppDismissedHash() => r'0e0f266490967350ceec051ec2664ec116aec0c2';

/// Whether the user said they'd keep the other app, so the "you can
/// uninstall it" banner stays away.

abstract class _$OtherAppDismissed extends $AsyncNotifier<bool> {
  FutureOr<bool> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<bool>, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<bool>, bool>,
              AsyncValue<bool>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
