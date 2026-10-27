import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/context_extensions.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../data/note_lock_secrets.dart';
import 'lock_secret_entry.dart';

enum _Step { current, choose, confirm }

/// Sets the account's PIN or pattern, or replaces it: the current one (or
/// the account password) first, then the new one twice. Needs the server.
/// Pops with true once saved.
class LockSecretSetupScreen extends ConsumerStatefulWidget {
  const LockSecretSetupScreen({
    super.key,
    required this.kind,
    required this.replacing,
  });

  final LockSecretKind kind;

  /// One is set already, so proof is asked for first.
  final bool replacing;

  /// Opens the screen; true once a PIN or pattern was saved.
  static Future<bool> open(
    BuildContext context, {
    required LockSecretKind kind,
    required bool replacing,
  }) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => LockSecretSetupScreen(kind: kind, replacing: replacing),
      ),
    );
    return saved == true;
  }

  @override
  ConsumerState<LockSecretSetupScreen> createState() =>
      _LockSecretSetupScreenState();
}

class _LockSecretSetupScreenState extends ConsumerState<LockSecretSetupScreen> {
  late _Step _step = widget.replacing ? _Step.current : _Step.choose;
  String? _current;
  String? _password;
  String? _chosen;

  bool get _isPin => widget.kind == LockSecretKind.pin;
  String get _what => _isPin ? 'PIN' : 'pattern';

  String get _title => switch (_step) {
    _Step.current => _isPin ? 'Enter your PIN' : 'Draw your pattern',
    _Step.choose =>
      _isPin
          ? (widget.replacing ? 'Choose a new PIN' : 'Choose a PIN')
          : (widget.replacing ? 'Draw a new pattern' : 'Draw a pattern'),
    _Step.confirm => _isPin ? 'Enter the PIN again' : 'Draw the pattern again',
  };

  String get _subtitle => switch (_step) {
    _Step.current => 'The one you use now',
    _Step.choose =>
      _isPin
          ? '4 to 12 digits. It opens every note you lock with a PIN.'
          : 'Join at least 4 dots. It opens every note you lock with a '
                'pattern.',
    _Step.confirm => 'To be sure',
  };

  Future<String?> _submit(String secret) async {
    switch (_step) {
      case _Step.current:
        final notes = ref.read(noteLockSecretsControllerProvider.notifier);
        final ok = await notes.verify(widget.kind, secret);
        // Not checkable here: the server decides when saving.
        if (ok == false) return 'That’s not your $_what';
        setState(() {
          _current = secret;
          _step = _Step.choose;
        });
        return null;
      case _Step.choose:
        if (!isValidLockSecret(widget.kind, secret)) {
          return _isPin
              ? 'Use 4 to 12 digits'
              : 'Join at least 4 dots, each once';
        }
        setState(() {
          _chosen = secret;
          _step = _Step.confirm;
        });
        return null;
      case _Step.confirm:
        if (secret != _chosen) {
          setState(() {
            _chosen = null;
            _step = _Step.choose;
          });
          if (mounted) {
            AppSnackbar.showError(
              context,
              message: _isPin
                  ? 'The PINs didn’t match. Try again.'
                  : 'The patterns didn’t match. Try again.',
            );
          }
          return null;
        }
        return _save(secret);
    }
  }

  Future<String?> _save(String secret) async {
    try {
      await ref
          .read(noteLockSecretsControllerProvider.notifier)
          .setSecret(
            widget.kind,
            secret,
            current: _current,
            password: _password,
          );
      if (!mounted) return null;
      Navigator.of(context).pop(true);
      return null;
    } on LockSecretException catch (e) {
      if (e.isWrongProof && widget.replacing) {
        setState(() {
          _current = null;
          _password = null;
          _chosen = null;
          _step = _Step.current;
        });
        if (mounted) AppSnackbar.showError(context, message: e.message);
        return null;
      }
      return e.message;
    }
  }

  /// Forgot the old one: the account password stands in for it.
  Future<void> _usePassword() async {
    final password = await showDialog<String>(
      context: context,
      builder: (context) => const _PasswordDialog(),
    );
    if (password == null || password.isEmpty || !mounted) return;
    setState(() {
      _password = password;
      _current = null;
      _step = _Step.choose;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dims = context.dims;
    final hasPassword =
        ref.watch(noteLockSecretsControllerProvider).value?.hasPassword ?? true;
    return Scaffold(
      appBar: AppBar(title: Text(_isPin ? 'PIN' : 'Pattern')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(dims.pagePadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: dims.xs),
                Text(
                  _subtitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
                SizedBox(height: dims.md),
                LockSecretEntry(
                  // A fresh pad for each step.
                  key: ValueKey(_step),
                  kind: widget.kind,
                  onSubmit: _submit,
                ),
                if (_step == _Step.current && hasPassword) ...[
                  SizedBox(height: dims.md),
                  TextButton(
                    onPressed: _usePassword,
                    child: const Text('Forgot? Use your password'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog();

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Your account password'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        obscureText: true,
        decoration: const InputDecoration(labelText: 'Password'),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Continue'),
        ),
      ],
    );
  }
}
