import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/context_extensions.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/settings_row.dart';
import '../../notes/data/repository/notes_repository.dart';
import '../../notes/domain/note.dart';
import '../data/note_lock_secrets.dart';
import 'lock_secret_setup_screen.dart';
import 'note_lock_session.dart';

IconData noteLockIcon(NoteLock lock) => switch (lock) {
  NoteLock.biometric => LucideIcons.fingerprint,
  NoteLock.pin => LucideIcons.rectangleEllipsis,
  NoteLock.pattern => LucideIcons.grip,
  NoteLock.tap => LucideIcons.pointer,
};

String _lockSubtitle(NoteLock lock) => switch (lock) {
  NoteLock.biometric => 'Or your phone’s own screen lock',
  NoteLock.pin => 'One PIN for all your locked notes',
  NoteLock.pattern => 'One pattern for all your locked notes',
  NoteLock.tap => 'Hides the note until you tap',
};

/// Asks which lock to use, biometric first; null if dismissed.
Future<NoteLock?> pickNoteLock(BuildContext context, {NoteLock? current}) {
  return AppBottomSheet.show<NoteLock>(
    context,
    builder: (context) => AppBottomSheet(
      icon: LucideIcons.lock,
      title: current == null ? 'Lock' : 'Change lock',
      subtitle: 'What opens the note',
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          context.dims.md,
          0,
          context.dims.md,
          context.dims.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final lock in NoteLock.values)
              SettingsSelectRow(
                key: ValueKey('pick-lock-${lock.name}'),
                title: lock.label,
                subtitle: _lockSubtitle(lock),
                icon: noteLockIcon(lock),
                isSelected: lock == current,
                onTap: () => Navigator.of(context).pop(lock),
              ),
          ],
        ),
      ),
    ),
  );
}

LockSecretKind? _secretFor(NoteLock lock) => switch (lock) {
  NoteLock.pin => LockSecretKind.pin,
  NoteLock.pattern => LockSecretKind.pattern,
  _ => null,
};

/// A PIN or pattern lock needs one on the account: made here the first
/// time. False when there is none and none was made.
Future<bool> _ensureSecret(
  BuildContext context,
  WidgetRef ref,
  NoteLock lock,
) async {
  final kind = _secretFor(lock);
  if (kind == null) return true;
  final controller = ref.read(noteLockSecretsControllerProvider.notifier);
  final cached = await ref.read(noteLockSecretsControllerProvider.future);
  if (cached.has(kind)) return true;
  // Maybe set on another device meanwhile.
  final fresh = await controller.refresh();
  if (fresh?.has(kind) ?? false) return true;
  if (!context.mounted) return false;
  if (fresh == null) {
    AppSnackbar.showError(
      context,
      message: kind == LockSecretKind.pin
          ? 'Setting a PIN needs a connection to the server'
          : 'Setting a pattern needs a connection to the server',
    );
    return false;
  }
  return LockSecretSetupScreen.open(context, kind: kind, replacing: false);
}

/// Lock… / Change lock… on an open note. It stays open (unlocked for this
/// session).
Future<void> lockOpenNote(
  BuildContext context,
  WidgetRef ref,
  Note note,
) async {
  final lock = await pickNoteLock(context, current: note.lock);
  if (lock == null || lock == note.lock || !context.mounted) return;
  if (!await _ensureSecret(context, ref, lock) || !context.mounted) return;
  ref.read(noteLockSessionProvider.notifier).unlock(note.id);
  await ref.read(notesRepositoryProvider).setLock([note.id], lock);
  if (!context.mounted) return;
  AppSnackbar.showSuccess(
    context,
    message: note.lock == null
        ? 'Locked with ${_lockName(lock)}'
        : 'Now locked with ${_lockName(lock)}',
    icon: LucideIcons.lock,
  );
}

/// Remove lock, on an open (so unlocked) note.
Future<void> unlockOpenNote(
  BuildContext context,
  WidgetRef ref,
  Note note,
) async {
  await ref.read(notesRepositoryProvider).setLock([note.id], null);
  if (!context.mounted) return;
  AppSnackbar.showSuccess(
    context,
    message: 'Lock removed',
    icon: LucideIcons.lockOpen,
  );
}

/// Lock… for the selected notes. Locked notes not opened this session keep
/// their lock: it can't be changed without opening them. Returns whether
/// anything was locked.
Future<bool> lockSelectedNotes(
  BuildContext context,
  WidgetRef ref,
  List<Note> notes,
) async {
  final unlocked = ref.read(noteLockSessionProvider);
  final changeable = [
    for (final note in notes)
      if (!isNoteHidden(note, unlocked)) note,
  ];
  final skipped = notes.length - changeable.length;
  if (changeable.isEmpty) {
    AppSnackbar.showError(
      context,
      message: notes.length == 1
          ? 'Open this note to change its lock'
          : 'Open these notes to change their locks',
    );
    return false;
  }
  final current = changeable.map((n) => n.lock).toSet();
  final lock = await pickNoteLock(
    context,
    current: current.length == 1 ? current.first : null,
  );
  if (lock == null || !context.mounted) return false;
  if (!await _ensureSecret(context, ref, lock) || !context.mounted) {
    return false;
  }
  await ref.read(notesRepositoryProvider).setLock([
    for (final note in changeable) note.id,
  ], lock);
  if (!context.mounted) return true;
  final count = changeable.length;
  final locked = '$count ${count == 1 ? 'note' : 'notes'}';
  AppSnackbar.showSuccess(
    context,
    message: skipped == 0
        ? 'Locked $locked'
        : 'Locked $locked. $skipped locked '
              '${skipped == 1 ? 'note wasn’t' : 'notes weren’t'} '
              'changed: open ${skipped == 1 ? 'it' : 'them'} first.',
    icon: LucideIcons.lock,
  );
  return true;
}

String _lockName(NoteLock lock) => switch (lock) {
  NoteLock.biometric => 'fingerprint or face',
  NoteLock.pin => 'your PIN',
  NoteLock.pattern => 'your pattern',
  NoteLock.tap => 'a tap',
};
