import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/router/app_routes.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/context_extensions.dart';
import '../../../core/theme/tokens/anchor_tokens.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/page_bar.dart';
import '../../../l10n/l10n.dart';
import '../../notes/data/repository/notes_repository.dart';
import '../../notes/domain/note.dart';
import '../../notes/presentation/widgets/note_surface.dart';
import '../data/biometric_unlock.dart';
import '../data/note_lock_secrets.dart';
import 'lock_secret_entry.dart';
import 'note_lock_session.dart';

/// Shows [child] (the note, its history) only once its lock is opened this
/// session; an unlock page until then. Once shown, the note stays behind
/// the unlock page if the session ends while it is open, so nothing typed
/// is lost.
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
  bool _wasLocked = false;

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
      // Nothing of the note until it is known whether it's locked.
      return NoteSurface(
        appearance: NoteAppearance.of(context, widget.note?.background),
      );
    }
    final note = _note;
    final locked = note != null && isNoteHidden(note, unlocked);
    if (!locked) _childShown = true;
    if (locked && !_wasLocked) {
      // The keyboard goes with the note.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => FocusManager.instance.primaryFocus?.unfocus(),
      );
    }
    _wasLocked = locked;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (_childShown)
          Offstage(
            offstage: locked,
            child: TickerMode(enabled: !locked, child: widget.child),
          ),
        if (locked)
          NoteLockScreen(
            note: note,
            onUnlocked: () =>
                ref.read(noteLockSessionProvider.notifier).unlock(note.id),
          ),
      ],
    );
  }
}

/// What a locked note shows instead of itself: its title, a lock and the
/// way to open it, on the note's own colour.
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
    final reason = context.l10n.lockBiometricReason(_titleOf(context));
    setState(() {
      _prompting = true;
      _message = null;
    });
    final outcome = await ref
        .read(biometricUnlockProvider)
        .authenticate(reason);
    if (!mounted) return;
    setState(() => _prompting = false);
    switch (outcome) {
      case BiometricOutcome.unlocked:
        widget.onUnlocked();
      case BiometricOutcome.failed:
        break;
      case BiometricOutcome.lockedOut:
        setState(() => _message = context.l10n.lockTooManyTries);
      case BiometricOutcome.unavailable:
        final kind = await _fallback();
        if (mounted) setState(() => _kind = kind);
    }
  }

  Future<String?> _check(LockSecretKind kind, String secret) async {
    final l10n = context.l10n;
    final ok = await ref
        .read(noteLockSecretsControllerProvider.notifier)
        .verify(kind, secret);
    if (ok == true) {
      widget.onUnlocked();
      return null;
    }
    if (ok == null) return l10n.lockCantCheck;
    return l10n.lockWrong(kind.name);
  }

  String _titleOf(BuildContext context) =>
      widget.note.hasTitle ? widget.note.title : context.l10n.lockUntitled;

  void _back() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.maybePop();
    } else if (context.isCupertino) {
      context.go(AppRoutes.home);
    } else {
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.anchor;
    final density = context.density;
    final appearance = NoteAppearance.of(context, widget.note.background);
    final kind = _kind;

    final Widget unlock = switch (kind) {
      null => const SizedBox(height: AnchorTokens.space48),
      NoteLock.tap => AppButton(
        key: const ValueKey('tap-to-unlock'),
        label: l10n.lockTapToUnlock,
        icon: LucideIcons.lockOpen,
        onPressed: widget.onUnlocked,
      ),
      NoteLock.biometric => AppButton(
        key: const ValueKey('biometric-unlock'),
        label: l10n.lockUnlock,
        icon: LucideIcons.fingerprint,
        onPressed: _prompting ? null : _prompt,
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
      NoteLock.pin => l10n.lockEnterPin,
      NoteLock.pattern => l10n.lockDrawPattern,
      NoteLock.biometric => l10n.lockUseBiometric,
      _ => null,
    };

    final top = MediaQuery.paddingOf(context).top + PageBar.heightOf(context);
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          NoteSurface(appearance: appearance),
          Padding(
            padding: EdgeInsets.only(top: top),
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  AnchorTokens.spaceGutterPhone,
                  density.space24,
                  AnchorTokens.spaceGutterPhone,
                  context.safeBottom + density.space24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: AnchorTokens.space48,
                      height: AnchorTokens.space48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: appearance.colors.surface,
                        border: Border.all(color: appearance.colors.border),
                      ),
                      child: Icon(
                        LucideIcons.lock,
                        size: AnchorTokens.sizeIconLarge,
                        color: colors.appText,
                      ),
                    ),
                    SizedBox(height: density.space16),
                    Text(
                      _titleOf(context),
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: context.noteTypography.title.copyWith(
                        color: colors.appText,
                      ),
                    ),
                    if (hint != null) ...[
                      SizedBox(height: density.space8),
                      Text(
                        hint,
                        textAlign: TextAlign.center,
                        style: AppTypography.secondary.copyWith(
                          color: appearance.colors.muted,
                        ),
                      ),
                    ],
                    if (_message case final message?) ...[
                      SizedBox(height: density.space12),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: AppTypography.secondary.copyWith(
                          color: colors.statusDanger,
                        ),
                      ),
                    ],
                    SizedBox(height: density.space24),
                    unlock,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: PageBar(
              color: appearance.colors.bg,
              leading: PageBackButton(onPressed: _back),
            ),
          ),
        ],
      ),
    );
  }
}
