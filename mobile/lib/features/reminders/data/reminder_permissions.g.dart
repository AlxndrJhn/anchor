// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reminder_permissions.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ReminderPermissionsController)
final reminderPermissionsControllerProvider =
    ReminderPermissionsControllerProvider._();

final class ReminderPermissionsControllerProvider
    extends
        $AsyncNotifierProvider<
          ReminderPermissionsController,
          ReminderPermissions
        > {
  ReminderPermissionsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reminderPermissionsControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$reminderPermissionsControllerHash();

  @$internal
  @override
  ReminderPermissionsController create() => ReminderPermissionsController();
}

String _$reminderPermissionsControllerHash() =>
    r'1b4a07715a85b2a11e0afeae3dccf5fc2bfdb9e6';

abstract class _$ReminderPermissionsController
    extends $AsyncNotifier<ReminderPermissions> {
  FutureOr<ReminderPermissions> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<ReminderPermissions>, ReminderPermissions>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<ReminderPermissions>, ReminderPermissions>,
              AsyncValue<ReminderPermissions>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
