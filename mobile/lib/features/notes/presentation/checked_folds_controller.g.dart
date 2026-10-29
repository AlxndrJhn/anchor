// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'checked_folds_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(CheckedFolds)
final checkedFoldsProvider = CheckedFoldsProvider._();

final class CheckedFoldsProvider
    extends $NotifierProvider<CheckedFolds, Set<String>> {
  CheckedFoldsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'checkedFoldsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$checkedFoldsHash();

  @$internal
  @override
  CheckedFolds create() => CheckedFolds();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Set<String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Set<String>>(value),
    );
  }
}

String _$checkedFoldsHash() => r'6685d5e6132fe7f542648cb6f19e57678eaeb372';

abstract class _$CheckedFolds extends $Notifier<Set<String>> {
  Set<String> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<Set<String>, Set<String>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Set<String>, Set<String>>,
              Set<String>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
