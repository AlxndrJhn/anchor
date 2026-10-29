// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reminder_tap_handler.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Cold-start taps go through `initializeApp`.

@ProviderFor(ReminderTapHandler)
final reminderTapHandlerProvider = ReminderTapHandlerProvider._();

/// Cold-start taps go through `initializeApp`.
final class ReminderTapHandlerProvider
    extends $NotifierProvider<ReminderTapHandler, void> {
  /// Cold-start taps go through `initializeApp`.
  ReminderTapHandlerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reminderTapHandlerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$reminderTapHandlerHash();

  @$internal
  @override
  ReminderTapHandler create() => ReminderTapHandler();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$reminderTapHandlerHash() =>
    r'ea74bf1c591a1038133043fe8d6caaf218565f96';

/// Cold-start taps go through `initializeApp`.

abstract class _$ReminderTapHandler extends $Notifier<void> {
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
