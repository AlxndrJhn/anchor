import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/storage/preferences_repository.dart';
import 'notification_gateway.dart';

part 'reminder_permissions.g.dart';

@immutable
class ReminderPermissions {
  const ReminderPermissions({
    required this.canNotify,
    required this.canBeExact,
    required this.needsExactAlarmPermission,
  });

  final bool canNotify;
  final bool canBeExact;

  /// Only Android gates exact timing.
  final bool needsExactAlarmPermission;

  bool get canRingOnTime =>
      canNotify && (canBeExact || !needsExactAlarmPermission);

  @override
  bool operator ==(Object other) =>
      other is ReminderPermissions &&
      other.canNotify == canNotify &&
      other.canBeExact == canBeExact &&
      other.needsExactAlarmPermission == needsExactAlarmPermission;

  @override
  int get hashCode =>
      Object.hash(canNotify, canBeExact, needsExactAlarmPermission);
}

@Riverpod(keepAlive: true)
class ReminderPermissionsController extends _$ReminderPermissionsController {
  AppLifecycleListener? _lifecycle;
  bool wasPromptedThisRun = false;

  @override
  Future<ReminderPermissions> build() {
    _lifecycle = AppLifecycleListener(onResume: refresh);
    ref.onDispose(() {
      _lifecycle?.dispose();
      _lifecycle = null;
    });
    return _read();
  }

  Future<ReminderPermissions> _read() async {
    final gateway = ref.read(notificationGatewayProvider);
    return ReminderPermissions(
      canNotify: await gateway.hasPermission(),
      canBeExact: await gateway.canScheduleExact(),
      needsExactAlarmPermission: gateway.requiresExactAlarmPermission,
    );
  }

  Future<ReminderPermissions> refresh() async {
    final permissions = await _read();
    state = AsyncData(permissions);
    return permissions;
  }

  /// Once the system has been refused, later calls return the standing
  /// answer (Android 13+ shows its dialog a second time first).
  Future<bool> requestNotifications() async {
    final granted = await ref
        .read(notificationGatewayProvider)
        .requestPermission();
    await refresh();
    return granted;
  }

  /// Returns once Android's alarms screen opens, before the user decides.
  Future<void> openExactSettings() =>
      ref.read(notificationGatewayProvider).requestExactPermission();

  Future<bool> hasAskedNotifications() =>
      ref.read(preferencesRepositoryProvider).getNotificationsAsked();

  Future<void> markNotificationsAsked() =>
      ref.read(preferencesRepositoryProvider).setNotificationsAsked(true);

  Future<bool> hasOfferedExact() =>
      ref.read(preferencesRepositoryProvider).getExactAlarmsOffered();

  Future<void> markExactOffered() =>
      ref.read(preferencesRepositoryProvider).setExactAlarmsOffered(true);
}
