// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'note_lock_session.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The locked notes opened since the phone was last locked. Kept in memory
/// only, so it also ends with the app's process. Switching apps keeps it;
/// the screen turning off ends it ("screenOff" from MainActivity, or, if
/// that came while Flutter wasn't listening, "takeScreenOff" on resume).

@ProviderFor(NoteLockSession)
final noteLockSessionProvider = NoteLockSessionProvider._();

/// The locked notes opened since the phone was last locked. Kept in memory
/// only, so it also ends with the app's process. Switching apps keeps it;
/// the screen turning off ends it ("screenOff" from MainActivity, or, if
/// that came while Flutter wasn't listening, "takeScreenOff" on resume).
final class NoteLockSessionProvider
    extends $NotifierProvider<NoteLockSession, Set<String>> {
  /// The locked notes opened since the phone was last locked. Kept in memory
  /// only, so it also ends with the app's process. Switching apps keeps it;
  /// the screen turning off ends it ("screenOff" from MainActivity, or, if
  /// that came while Flutter wasn't listening, "takeScreenOff" on resume).
  NoteLockSessionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'noteLockSessionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$noteLockSessionHash();

  @$internal
  @override
  NoteLockSession create() => NoteLockSession();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Set<String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Set<String>>(value),
    );
  }
}

String _$noteLockSessionHash() => r'626d2967426728b534deac16f539c3eb18054cbd';

/// The locked notes opened since the phone was last locked. Kept in memory
/// only, so it also ends with the app's process. Switching apps keeps it;
/// the screen turning off ends it ("screenOff" from MainActivity, or, if
/// that came while Flutter wasn't listening, "takeScreenOff" on resume).

abstract class _$NoteLockSession extends $Notifier<Set<String>> {
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
