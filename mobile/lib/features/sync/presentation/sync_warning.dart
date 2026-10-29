import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/session/session_expired_provider.dart';
import '../../../core/widgets/anchor_dialog.dart';
import '../../../core/widgets/notice.dart';
import '../../../l10n/l10n.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/sync_compatibility.dart';
import 'compatibility_messages.dart';

class SyncWarning extends ConsumerWidget {
  const SyncWarning({super.key, this.padding = EdgeInsets.zero});

  /// Applied only while the card shows.
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final banner = _banner(context, ref);
    return banner == null
        ? const SizedBox.shrink()
        : Padding(padding: padding, child: banner);
  }

  Widget? _banner(BuildContext context, WidgetRef ref) {
    if (ref.watch(sessionExpiredProvider)) {
      return Notice(
        kind: NoticeKind.warn,
        icon: LucideIcons.logIn,
        title: context.l10n.syncSignedOutLead,
        text: context.l10n.syncSignedOutText,
        onTap: () => _signInAgain(context, ref),
      );
    }
    final compatibility = ref.watch(syncCompatibilityProvider).value;
    final words = compatibility == null
        ? null
        : compatibilityMessagesOf(compatibility, context.l10n);
    if (words == null) return null;
    return Notice(
      kind: NoticeKind.warn,
      icon: LucideIcons.triangleAlert,
      title: words.lead,
      text: words.text,
      onTap: () => showAnchorDialog(
        context,
        title: words.title,
        message: context.l10n.syncPausedMessage(words.message),
        confirmLabel: context.l10n.commonOk,
        hasCancel: false,
        icon: LucideIcons.triangleAlert,
      ),
    );
  }

  Future<void> _signInAgain(BuildContext context, WidgetRef ref) async {
    final ok = await showAnchorDialog(
      context,
      title: context.l10n.syncSignInAgainTitle,
      message: context.l10n.syncSignInAgainMessage,
      confirmLabel: context.l10n.authSignIn,
      cancelLabel: context.l10n.commonLater,
      icon: LucideIcons.logIn,
    );
    if (ok) await ref.read(authControllerProvider.notifier).logout();
  }
}
