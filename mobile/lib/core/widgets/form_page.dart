import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/l10n.dart';
import '../network/connectivity_provider.dart';
import '../theme/context_extensions.dart';
import '../theme/tokens/anchor_tokens.dart';
import 'app_scaffold.dart';
import 'notice.dart';
import 'reveal.dart';

class FormPage extends StatelessWidget {
  const FormPage({
    super.key,
    required this.title,
    required this.children,
    this.isTitleShown = true,
    this.showBack = true,
    this.bottomBar,
    this.cover,
    this.topPadding,
    this.bottomPadding = AnchorTokens.space24,
  });

  final String title;
  final List<Widget> children;

  final bool isTitleShown;
  final bool showBack;
  final Widget? bottomBar;
  final Widget? cover;

  /// Null takes the density's 16.
  final double? topPadding;

  /// Ignored when there is a [bottomBar].
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: title,
      isTitleShown: isTitleShown,
      showBack: showBack,
      background: PageBackground.gradient,
      bottomBar: bottomBar,
      cover: cover,
      bottomPadding: bottomPadding,
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            16,
            topPadding ?? context.density.space16,
            16,
            0,
          ),
          sliver: SliverList.list(children: children),
        ),
      ],
    );
  }
}

class FormNotices extends ConsumerWidget {
  const FormNotices({super.key, this.errorMessage, this.offlineText});

  final String? errorMessage;

  /// Null says the form needs a connection to continue.
  final String? offlineText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!isOnline)
          Padding(
            padding: EdgeInsets.only(bottom: context.density.space16),
            child: Notice(
              icon: LucideIcons.cloudOff,
              text: offlineText ?? context.l10n.formOffline,
            ),
          ),
        Reveal(
          visible: errorMessage != null,
          child: Padding(
            padding: EdgeInsets.only(bottom: context.density.space16),
            child: Notice(
              icon: LucideIcons.circleAlert,
              text: errorMessage ?? '',
              kind: NoticeKind.danger,
            ),
          ),
        ),
      ],
    );
  }
}
