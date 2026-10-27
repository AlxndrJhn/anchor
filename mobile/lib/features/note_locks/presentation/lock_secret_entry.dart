import 'package:flutter/material.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/theme/context_extensions.dart';
import '../../../core/theme/tokens/anchor_tokens.dart';
import '../../../core/widgets/app_buttons.dart';
import '../data/note_lock_secrets.dart';
import 'lock_pads.dart';

/// A PIN pad or pattern grid that hands what is entered to [onSubmit],
/// which answers with an error to show (and a shake), or null when it was
/// taken.
class LockSecretEntry extends StatefulWidget {
  const LockSecretEntry({
    super.key,
    required this.kind,
    required this.onSubmit,
  });

  final LockSecretKind kind;
  final Future<String?> Function(String secret) onSubmit;

  @override
  State<LockSecretEntry> createState() => _LockSecretEntryState();
}

class _LockSecretEntryState extends State<LockSecretEntry> {
  String? _error;
  int _wrong = 0;
  bool _busy = false;

  Future<void> _submit(String secret) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await widget.onSubmit(secret);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
      if (error != null) _wrong++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: AnchorTokens.space48,
          child: Center(
            child: _busy
                ? Spinner(
                    size: AnchorTokens.sizeIconMedium,
                    color: colors.appMuted,
                  )
                : Semantics(
                    liveRegion: true,
                    child: Text(
                      _error ?? '',
                      key: const ValueKey('lock-entry-error'),
                      textAlign: TextAlign.center,
                      style: AppTypography.secondary.copyWith(
                        color: colors.statusDanger,
                      ),
                    ),
                  ),
          ),
        ),
        SizedBox(height: context.density.space8),
        ShakeOnChange(
          trigger: _wrong,
          child: switch (widget.kind) {
            LockSecretKind.pin => PinPad(
              onSubmit: _submit,
              enabled: !_busy,
              clearSignal: _wrong,
            ),
            LockSecretKind.pattern => LockPatternPad(
              onComplete: _submit,
              enabled: !_busy,
              isError: _error != null,
            ),
          },
        ),
      ],
    );
  }
}
