// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tags_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(TagsController)
final tagsControllerProvider = TagsControllerProvider._();

final class TagsControllerProvider
    extends $StreamNotifierProvider<TagsController, List<Tag>> {
  TagsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'tagsControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$tagsControllerHash();

  @$internal
  @override
  TagsController create() => TagsController();
}

String _$tagsControllerHash() => r'004299f79e93751882e2f1c38ec7b655b0398e88';

abstract class _$TagsController extends $StreamNotifier<List<Tag>> {
  Stream<List<Tag>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<Tag>>, List<Tag>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<Tag>>, List<Tag>>,
              AsyncValue<List<Tag>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Counts archived notes too.

@ProviderFor(tagNoteCounts)
final tagNoteCountsProvider = TagNoteCountsProvider._();

/// Counts archived notes too.

final class TagNoteCountsProvider
    extends
        $FunctionalProvider<
          Map<String, int>,
          Map<String, int>,
          Map<String, int>
        >
    with $Provider<Map<String, int>> {
  /// Counts archived notes too.
  TagNoteCountsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'tagNoteCountsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$tagNoteCountsHash();

  @$internal
  @override
  $ProviderElement<Map<String, int>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Map<String, int> create(Ref ref) {
    return tagNoteCounts(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<String, int> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<String, int>>(value),
    );
  }
}

String _$tagNoteCountsHash() => r'e0ac5bbd57ee2b64d3450dd15f0e85f7ab718e22';

@ProviderFor(SelectedTagFilter)
final selectedTagFilterProvider = SelectedTagFilterProvider._();

final class SelectedTagFilterProvider
    extends $NotifierProvider<SelectedTagFilter, String?> {
  SelectedTagFilterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'selectedTagFilterProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$selectedTagFilterHash();

  @$internal
  @override
  SelectedTagFilter create() => SelectedTagFilter();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$selectedTagFilterHash() => r'7e560768b04e36343611fba6cfec57e773906b5d';

abstract class _$SelectedTagFilter extends $Notifier<String?> {
  String? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<String?, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String?, String?>,
              String?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
