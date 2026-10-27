import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/context_extensions.dart';
import '../../notes/data/repository/notes_repository.dart';
import '../../notes/domain/note.dart';
import '../data/biometric_unlock.dart';
import '../data/note_lock_secrets.dart';
import 'lock_secret_entry.dart';
import 'note_lock_session.dart';

/// Shows [child] (the note) only once its lock is opened this session; a
/// lock screen until then. The note stays behind the lock screen if the
/// session ends while it is open, so nothing typed is lost.
class NoteLockGate extends ConsumerStatefulWidget {
  const NoteLockGate({
    super.key,
    required this.noteId,
    this.note,
    required this.child,
  });

  final String noteId;

  /// The note as the list had it, so a lock shows without waiting.
  final Note? note;
  final Widget child;

  @override
  ConsumerState<NoteLockGate> createState() => _NoteLockGateState();
}

class _NoteLockGateState extends ConsumerState<NoteLockGate> {
  StreamSubscription<Note?>? _watch;
  Note? _note;
  late bool _known = widget.note != null;
  bool _childShown = false;

  @override
  void initState() {
    super.initState();
    _note = widget.note;
    _watch = ref
        .read(notesRepositoryProvider)
        .watchNote(widget.noteId)
        .listen(
          (note) {
            if (!mounted) return;
            setState(() {
              _note = note;
              _known = true;
            });
          },
          onError: (Object _) {
            if (mounted) setState(() => _known = true);
          },
        );
  }

  @override
  void dispose() {
    unawaited(_watch?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unlocked = ref.watch(noteLockSessionProvider);
    if (!_known) {
      return const Scaffold(body: SizedBox.shrink());
    }
    final note = _note;
    final locked = note != null && isNoteHidden(note, unlocked);
    if (!locked) _childShown = true;
    if (locked) {
      // The keyboard goes with the note.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => FocusManager.instance.primaryFocus?.unfocus(),
      );
    }

    return Stack(
      children: [
        if (_childShown)
          Offstage(
            offstage: locked,
            child: TickerMode(enabled: !locked, child: widget.child),
          ),
        if (locked)
          Positioned.fill(
            child: NoteLockScreen(
              note: note,
              onUnlocked: () =>
                  ref.read(noteLockSessionProvider.notifier).unlock(note.id),
            ),
          ),
      ],
    );
  }
}

/// What a locked note shows instead of itself: its title, a lock and the
/// way to open it.
class NoteLockScreen extends ConsumerStatefulWidget {
  const NoteLockScreen({
    super.key,
    required this.note,
    required this.onUnlocked,
  });

  final Note note;
  final VoidCallback onUnlocked;

  @override
  ConsumerState<NoteLockScreen> createState() => _NoteLockScreenState();
}

class _NoteLockScreenState extends ConsumerState<NoteLockScreen> {
  /// How the note opens here: its lock, or a stand-in when this device
  /// can't do that one. Null while that is being worked out.
  NoteLock? _kind;
  String? _message;
  bool _prompting = false;

  @override
  void initState() {
    super.initState();
    unawaited(_decide());
  }

  @override
  void didUpdateWidget(NoteLockScreen old) {
    super.didUpdateWidget(old);
    if (old.note.lock != widget.note.lock) unawaited(_decide());
  }

  Future<void> _decide() async {
    final lock = widget.note.lock ?? NoteLock.tap;
    var kind = lock;
    if (lock == NoteLock.biometric &&
        !await ref.read(biometricUnlockProvider).isAvailable()) {
      kind = await _fallback();
    }
    if (!mounted) return;
    setState(() => _kind = kind);
    if (kind == NoteLock.biometric) unawaited(_prompt());
  }

  /// A device with no fingerprint, face or screen lock: the PIN if there is
  /// one, else the pattern, else a tap.
  Future<NoteLock> _fallback() async {
    final notifier = ref.read(noteLockSecretsControllerProvider.notifier);
    var secrets = await ref.read(noteLockSecretsControllerProvider.future);
    if (!secrets.has(LockSecretKind.pin) &&
        !secrets.has(LockSecretKind.pattern)) {
      secrets = await notifier.refresh() ?? secrets;
    }
    if (secrets.has(LockSecretKind.pin)) return NoteLock.pin;
    if (secrets.has(LockSecretKind.pattern)) return NoteLock.pattern;
    return NoteLock.tap;
  }

  Future<void> _prompt() async {
    if (_prompting) return;
    setState(() {
      _prompting = true;
      _message = null;
    });
    final outcome = await ref
        .read(biometricUnlockProvider)
        .authenticate('Unlock “${_titleOf(widget.note)}”');
    if (!mounted) return;
    setState(() => _prompting = false);
    switch (outcome) {
      case BiometricOutcome.unlocked:
        widget.onUnlocked();
      case BiometricOutcome.failed:
        break;
      case BiometricOutcome.lockedOut:
        setState(
          () => _message = 'Too many tries. Unlock your phone, then try again.',
        );
      case BiometricOutcome.unavailable:
        final kind = await _fallback();
        if (mounted) setState(() => _kind = kind);
    }
  }

  Future<String?> _check(LockSecretKind kind, String secret) async {
    final ok = await ref
        .read(noteLockSecretsControllerProvider.notifier)
        .verify(kind, secret);
    if (ok == true) {
      widget.onUnlocked();
      return null;
    }
    if (ok == null) {
      return 'Can’t check it on this phone yet. Connect to the internet and '
          'try again.';
    }
    return kind == LockSecretKind.pin ? 'Wrong PIN' : 'Wrong pattern';
  }

  static String _titleOf(Note note) =>
      note.hasTitle ? note.title : 'Locked note';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dims = context.dims;
    final note = widget.note;
    final kind = _kind;

    final Widget unlock = switch (kind) {
      null => const SizedBox(height: 48),
      NoteLock.tap => FilledButton.icon(
        key: const ValueKey('tap-to-unlock'),
        onPressed: widget.onUnlocked,
        icon: const Icon(LucideIcons.lockOpen),
        label: const Text('Tap to unlock'),
      ),
      NoteLock.biometric => FilledButton.icon(
        key: const ValueKey('biometric-unlock'),
        onPressed: _prompting ? null : _prompt,
        icon: const Icon(LucideIcons.fingerprint),
        label: const Text('Unlock'),
      ),
      NoteLock.pin => LockSecretEntry(
        kind: LockSecretKind.pin,
        onSubmit: (pin) => _check(LockSecretKind.pin, pin),
      ),
      NoteLock.pattern => LockSecretEntry(
        kind: LockSecretKind.pattern,
        onSubmit: (pattern) => _check(LockSecretKind.pattern, pattern),
      ),
    };

    final hint = switch (kind) {
      NoteLock.pin => 'Enter your PIN',
      NoteLock.pattern => 'Draw your pattern',
      NoteLock.biometric => 'Use your fingerprint, face or screen lock',
      _ => null,
    };

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(dims.pagePadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons.lock,
                  size: 40,
                  color: theme.colorScheme.primary,
                ),
                SizedBox(height: dims.md),
                Text(
                  _titleOf(note),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (hint != null) ...[
                  SizedBox(height: dims.xs),
                  Text(hint, style: theme.textTheme.bodyMedium),
                ],
                if (_message != null) ...[
                  SizedBox(height: dims.sm),
                  Text(
                    _message!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
                SizedBox(height: dims.lg),
                unlock,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
