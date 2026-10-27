import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/motion/haptics.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/choice_sheet.dart';
import '../../../l10n/l10n.dart';
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

String noteLockLabel(NoteLock lock, AppLocalizations l10n) => switch (lock) {
  NoteLock.biometric => l10n.lockKindBiometric,
  NoteLock.pin => l10n.lockKindPin,
  NoteLock.pattern => l10n.lockKindPattern,
  NoteLock.tap => l10n.lockKindTap,
};

String _lockHelp(NoteLock lock, AppLocalizations l10n) => switch (lock) {
  NoteLock.biometric => l10n.lockKindBiometricHelp,
  NoteLock.pin => l10n.lockKindPinHelp,
  NoteLock.pattern => l10n.lockKindPatternHelp,
  NoteLock.tap => l10n.lockKindTapHelp,
};

/// Asks which lock to use, biometric first; null if dismissed.
Future<NoteLock?> pickNoteLock(BuildContext context, {NoteLock? current}) {
  final l10n = context.l10n;
  return showChoiceSheet<NoteLock>(
    context,
    title: current == null ? l10n.lockSheetTitle : l10n.lockSheetChangeTitle,
    subtitle: l10n.lockSheetSubtitle,
    choices: [
      for (final lock in NoteLock.values)
        SheetChoice(
          value: lock,
          icon: noteLockIcon(lock),
          label: noteLockLabel(lock, l10n),
          subtitle: _lockHelp(lock, l10n),
          checked: current == null ? null : lock == current,
        ),
    ],
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
  final l10n = context.l10n;
  final controller = ref.read(noteLockSecretsControllerProvider.notifier);
  final cached = await ref.read(noteLockSecretsControllerProvider.future);
  if (cached.has(kind)) return true;
  // Maybe set on another device meanwhile.
  final fresh = await controller.refresh();
  if (fresh?.has(kind) ?? false) return true;
  if (!context.mounted) return false;
  if (fresh == null) {
    AppSnackbar.show(
      context,
      l10n.lockNeedsServer(kind.name),
      kind: SnackbarKind.error,
    );
    return false;
  }
  return LockSecretSetupScreen.open(context, kind: kind, replacing: false);
}

/// Lock / Change lock on an open note. It stays open (unlocked for this
/// session).
Future<void> lockOpenNote(
  BuildContext context,
  WidgetRef ref,
  Note note,
) async {
  final l10n = context.l10n;
  final lock = await pickNoteLock(context, current: note.lock);
  if (lock == null || lock == note.lock || !context.mounted) return;
  if (!await _ensureSecret(context, ref, lock) || !context.mounted) return;
  ref.read(noteLockSessionProvider.notifier).unlock(note.id);
  await ref.read(notesRepositoryProvider).setLock([note.id], lock);
  Haptics.success();
  if (!context.mounted) return;
  AppSnackbar.show(
    context,
    note.lock == null
        ? l10n.noteLockedWith(lock.name)
        : l10n.noteLockChanged(lock.name),
  );
}

/// Remove lock, on an open (so unlocked) note. Undo puts it back.
Future<void> unlockOpenNote(
  BuildContext context,
  WidgetRef ref,
  Note note,
) async {
  final was = note.lock;
  if (was == null) return;
  final repo = ref.read(notesRepositoryProvider);
  ref.read(noteLockSessionProvider.notifier).unlock(note.id);
  await repo.setLock([note.id], null);
  if (!context.mounted) return;
  AppSnackbar.show(
    context,
    context.l10n.noteLockRemoved,
    actionLabel: context.l10n.commonUndo,
    onAction: () => repo.setLock([note.id], was),
  );
}

/// Lock for the selected notes. Locked notes not opened this session keep
/// their lock: it can't be changed without opening them. [beforeChange] runs
/// once a lock is chosen, just before the notes change. Returns whether
/// anything was locked.
Future<bool> lockSelectedNotes(
  BuildContext context,
  WidgetRef ref,
  List<Note> notes, {
  FutureOr<void> Function()? beforeChange,
}) async {
  final l10n = context.l10n;
  final unlocked = ref.read(noteLockSessionProvider);
  final changeable = [
    for (final note in notes)
      if (!isNoteHidden(note, unlocked)) note,
  ];
  final skipped = notes.length - changeable.length;
  if (changeable.isEmpty) {
    AppSnackbar.show(
      context,
      l10n.notesLockOpenFirst(notes.length),
      kind: SnackbarKind.info,
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
  await beforeChange?.call();
  // Their cards hide at once: locking from the list puts them away.
  final ids = [for (final note in changeable) note.id];
  await ref.read(notesRepositoryProvider).setLock(ids, lock);
  Haptics.success();
  if (!context.mounted) return true;
  AppSnackbar.show(
    context,
    skipped == 0
        ? l10n.notesLocked(ids.length)
        : l10n.notesLockedSome(ids.length),
  );
  return true;
}
