// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'note_attachments_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(noteAttachmentsRepository)
final noteAttachmentsRepositoryProvider = NoteAttachmentsRepositoryProvider._();

final class NoteAttachmentsRepositoryProvider
    extends
        $FunctionalProvider<
          NoteAttachmentsRepository,
          NoteAttachmentsRepository,
          NoteAttachmentsRepository
        >
    with $Provider<NoteAttachmentsRepository> {
  NoteAttachmentsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'noteAttachmentsRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$noteAttachmentsRepositoryHash();

  @$internal
  @override
  $ProviderElement<NoteAttachmentsRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  NoteAttachmentsRepository create(Ref ref) {
    return noteAttachmentsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NoteAttachmentsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NoteAttachmentsRepository>(value),
    );
  }
}

String _$noteAttachmentsRepositoryHash() =>
    r'3b5ae36991f659fc5307c618f89df3687a064b1d';
