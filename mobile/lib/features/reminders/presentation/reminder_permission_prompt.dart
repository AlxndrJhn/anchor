import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/widgets/anchor_dialog.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../l10n/l10n.dart';
import '../data/reminder_permissions.dart';

enum ReminderPermissionTrigger { userSet, synced }

Future<void> ensureReminderPermissions(
  BuildContext context,
  WidgetRef ref, {
  required ReminderPermissionTrigger trigger,
}) async {
  final controller = ref.read(reminderPermissionsControllerProvider.notifier);
  controller.wasPromptedThisRun = true;
  var permissions = await controller.refresh();

  if (!permissions.canNotify) {
    final isSynced = trigger == ReminderPermissionTrigger.synced;
    if (await controller.hasAskedNotifications()) {
      if (!isSynced && context.mounted) _showTurnOnNotifications(context);
      return;
    }
    if (isSynced) {
      if (!context.mounted) return;
      final shouldContinue = await showAnchorDialog(
        context,
        icon: LucideIcons.bellRing,
        title: context.l10n.reminderNotifyTitle,
        message: context.l10n.reminderNotifyMessage,
        cancelLabel: context.l10n.commonNotNow,
        confirmLabel: context.l10n.commonContinue,
      );
      if (!shouldContinue) return;
    }

    await controller.markNotificationsAsked();
    if (!await controller.requestNotifications()) {
      if (context.mounted) _showTurnOnNotifications(context);
      return;
    }
    permissions = await controller.refresh();
  }

  if (!permissions.needsExactAlarmPermission || permissions.canBeExact) return;
  if (await controller.hasOfferedExact()) return;
  // Offered once, whatever the answer.
  await controller.markExactOffered();

  if (!context.mounted) return;
  final open = await showAnchorDialog(
    context,
    icon: LucideIcons.alarmClock,
    title: context.l10n.reminderExactTitle,
    message: context.l10n.reminderExactMessage,
    cancelLabel: context.l10n.commonNotNow,
    confirmLabel: context.l10n.commonOpenSettings,
  );
  if (open) await controller.openExactSettings();
}

void _showTurnOnNotifications(BuildContext context) => AppSnackbar.show(
  context,
  context.l10n.reminderNotificationsOff,
  kind: SnackbarKind.info,
);
