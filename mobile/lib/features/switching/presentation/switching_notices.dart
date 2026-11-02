import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/notice.dart';
import '../../../l10n/l10n.dart';
import '../data/other_anchor_app.dart';

/// On the server page, while the app being switched from is installed:
/// let it sync first, since its notes reach this app only through the
/// server.
class SwitchingFromNotice extends ConsumerWidget {
  const SwitchingFromNotice({super.key, this.padding = EdgeInsets.zero});

  /// Applied only while the notice shows.
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final other = ref.watch(otherAnchorAppControllerProvider).value;
    if (other == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    return Padding(
      padding: padding,
      child: Notice(
        icon: LucideIcons.arrowRightLeft,
        title: l10n.switchingFromTitle(other.label),
        text: l10n.switchingFromText,
        action: AppButton(
          label: l10n.switchingOpen(other.label),
          kind: AppButtonKind.secondary,
          size: AppButtonSize.small,
          isExpanded: false,
          onPressed: other.open,
        ),
      ),
    );
  }
}
