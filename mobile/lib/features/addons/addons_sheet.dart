import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/motion/haptics.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/context_extensions.dart';
import '../../core/theme/tokens/anchor_tokens.dart';
import '../../core/widgets/anchor_sheet.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/grouped_list.dart';
import '../../core/widgets/platform_switch.dart';
import '../../l10n/l10n.dart';
import 'addons.dart';

/// Settings › Appearance › Addons: the addons installed on the web, each
/// turned on or off here for every device.
Future<void> showAddonsSheet(BuildContext context) => showAnchorSheet<void>(
  context,
  semanticLabel: context.l10n.settingsAddons,
  canGrow: true,
  builder: (_) => const AddonsSheet(),
);

class AddonsSheet extends ConsumerWidget {
  const AddonsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = context.anchor;
    final addons = ref.watch(addonsControllerProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader(title: l10n.settingsAddons, showDone: true),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: AnchorTokens.space12,
              children: [
                Text(
                  l10n.addonsHelp,
                  style: AppTypography.secondary.copyWith(
                    color: colors.appMuted,
                  ),
                ),
                if (addons.isNotEmpty)
                  GroupedList(
                    semanticLabel: l10n.settingsAddons,
                    children: [
                      for (final addon in addons)
                        GroupedListTile(
                          leading: _AccentDot(addon: addon),
                          label: '${addon.name} ${addon.version}',
                          subtitle: [
                            ?addon.description,
                            if (addon.hasStyles) l10n.addonsStylesOnWeb,
                          ].join(' '),
                          trailing: PlatformSwitch(
                            value: addon.enabled,
                            semanticLabel: addon.name,
                            onChanged: (on) =>
                                _setEnabled(context, ref, addon, on),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SheetBottomSpace(),
      ],
    );
  }

  Future<void> _setEnabled(
    BuildContext context,
    WidgetRef ref,
    InstalledAddon addon,
    bool on,
  ) async {
    Haptics.selection();
    final l10n = context.l10n;
    try {
      await ref
          .read(addonsControllerProvider.notifier)
          .setEnabled(addon.id, on);
    } catch (_) {
      if (context.mounted) {
        AppSnackbar.show(context, l10n.addonsSwitchFailed(addon.name));
      }
    }
  }
}

/// The accent an addon's theme sets, in this mode; a plain dot without one.
class _AccentDot extends StatelessWidget {
  const _AccentDot({required this.addon});

  final InstalledAddon addon;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    final accent = addon.theme?.of(Theme.of(context).brightness)?['accent'];
    return SizedBox.square(
      dimension: AnchorTokens.sizeIconMedium,
      child: Center(
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accent ?? colors.appBorder,
            border: Border.all(color: colors.appText.withValues(alpha: 0.18)),
          ),
        ),
      ),
    );
  }
}
