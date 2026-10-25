// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'share_handler.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Opens a new note for whatever is shared to Anchor ("Share to…"), once
/// someone is signed in.

@ProviderFor(ShareHandler)
final shareHandlerProvider = ShareHandlerProvider._();

/// Opens a new note for whatever is shared to Anchor ("Share to…"), once
/// someone is signed in.
final class ShareHandlerProvider extends $NotifierProvider<ShareHandler, void> {
  /// Opens a new note for whatever is shared to Anchor ("Share to…"), once
  /// someone is signed in.
  ShareHandlerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'shareHandlerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$shareHandlerHash();

  @$internal
  @override
  ShareHandler create() => ShareHandler();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$shareHandlerHash() => r'97b41084b53e4783b6d92785362e5d255339c059';

/// Opens a new note for whatever is shared to Anchor ("Share to…"), once
/// someone is signed in.

abstract class _$ShareHandler extends $Notifier<void> {
  void build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<void, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<void, void>,
              void,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
