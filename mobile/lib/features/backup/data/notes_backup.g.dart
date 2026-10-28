// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notes_backup.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(notesBackup)
final notesBackupProvider = NotesBackupProvider._();

final class NotesBackupProvider
    extends $FunctionalProvider<NotesBackup, NotesBackup, NotesBackup>
    with $Provider<NotesBackup> {
  NotesBackupProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notesBackupProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notesBackupHash();

  @$internal
  @override
  $ProviderElement<NotesBackup> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  NotesBackup create(Ref ref) {
    return notesBackup(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NotesBackup value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NotesBackup>(value),
    );
  }
}

String _$notesBackupHash() => r'f8c36ccc86292170c960f46de4c68f6e9cc9a4e6';
