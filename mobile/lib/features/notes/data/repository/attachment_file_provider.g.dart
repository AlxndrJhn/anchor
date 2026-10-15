// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attachment_file_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Null while offline with no copy here. Never retries on its own; reloads
/// once back online.

@ProviderFor(attachmentFile)
final attachmentFileProvider = AttachmentFileFamily._();

/// Null while offline with no copy here. Never retries on its own; reloads
/// once back online.

final class AttachmentFileProvider
    extends $FunctionalProvider<AsyncValue<String?>, String?, FutureOr<String?>>
    with $FutureModifier<String?>, $FutureProvider<String?> {
  /// Null while offline with no copy here. Never retries on its own; reloads
  /// once back online.
  AttachmentFileProvider._({
    required AttachmentFileFamily super.from,
    required AttachmentFileKey super.argument,
  }) : super(
         retry: _noRetry,
         name: r'attachmentFileProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$attachmentFileHash();

  @override
  String toString() {
    return r'attachmentFileProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String?> create(Ref ref) {
    final argument = this.argument as AttachmentFileKey;
    return attachmentFile(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is AttachmentFileProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$attachmentFileHash() => r'27a70574d0104ffd79d30c00bd8404a7965f932c';

/// Null while offline with no copy here. Never retries on its own; reloads
/// once back online.

final class AttachmentFileFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<String?>, AttachmentFileKey> {
  AttachmentFileFamily._()
    : super(
        retry: _noRetry,
        name: r'attachmentFileProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Null while offline with no copy here. Never retries on its own; reloads
  /// once back online.

  AttachmentFileProvider call(AttachmentFileKey key) =>
      AttachmentFileProvider._(argument: key, from: this);

  @override
  String toString() => r'attachmentFileProvider';
}
