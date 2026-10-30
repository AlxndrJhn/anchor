import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/motion/haptics.dart';
import '../../../core/theme/context_extensions.dart';
import '../../../core/theme/tokens/anchor_tokens.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/grouped_list.dart';
import '../../../core/widgets/platform_switch.dart';
import '../../../l10n/l10n.dart';
import '../../notes/domain/quick_action.dart';
import '../../notes/presentation/quick_action_labels.dart';
import 'editor_preferences_controller.dart';

/// A note's top bar beside More, in order, and what More offers: each action
/// in the bar, in More, or turned off.
class QuickActionsSection extends ConsumerWidget {
  const QuickActionsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final preferences = ref.watch(editorPreferencesControllerProvider);
    final controller = ref.read(editorPreferencesControllerProvider.notifier);
    final bar = preferences.quickActions;
    final isFull = bar.length >= QuickAction.max;
    final gap = SizedBox(height: Section.gapOf(context));

    Widget tile(QuickAction action, int index) {
      final (:icon, :label) = action.iconAndLabel(l10n);
      final row = GroupedListTile(
        icon: icon,
        label: label,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            BarButton(
              icon: LucideIcons.circleMinus,
              label: l10n.settingsRemoveFromBar(label),
              size: BarButtonSize.small,
              onPressed: () => controller.setQuickActions([
                for (final quick in bar)
                  if (quick != action) quick,
              ]),
            ),
            ReorderableDragStartListener(
              index: index,
              child: SizedBox.square(
                dimension: AnchorTokens.sizeControlSmall,
                child: Icon(
                  LucideIcons.gripVertical,
                  size: AnchorTokens.sizeIconMedium,
                  color: context.anchor.appMuted,
                ),
              ),
            ),
          ],
        ),
      );
      return KeyedSubtree(
        key: ValueKey(action),
        child: index == 0
            ? row
            : GroupedList.lineAbove(
                context,
                row,
                start: GroupedListTile.textStart,
              ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Section(
          label: l10n.settingsQuickActions,
          child: bar.isEmpty
              ? GroupedList(
                  children: [
                    GroupedListTile(label: l10n.settingsQuickActionsEmpty),
                  ],
                )
              : Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: GroupedList.decorationOf(context),
                  child: ReorderableListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    proxyDecorator: (child, _, _) => Material(
                      color: GroupedList.fillOf(context),
                      elevation: 4,
                      child: child,
                    ),
                    onReorderItem: (from, to) {
                      Haptics.selection();
                      final actions = [...bar];
                      actions.insert(to, actions.removeAt(from));
                      controller.setQuickActions(actions);
                    },
                    children: [
                      for (final (index, action) in bar.indexed)
                        tile(action, index),
                    ],
                  ),
                ),
        ),
        SectionFooter(l10n.settingsQuickActionsHelp),
        gap,
        Section(
          label: l10n.settingsMoreActions,
          child: GroupedList(
            children: [
              for (final action in QuickAction.values)
                if (!bar.contains(action))
                  _MoreRow(
                    action: action,
                    isOn: !preferences.hiddenActions.contains(action),
                    canAddToBar: !isFull,
                    onAddToBar: () =>
                        controller.setQuickActions([...bar, action]),
                    onChanged: (isOn) =>
                        controller.setActionHidden(action, !isOn),
                  ),
            ],
          ),
        ),
        SectionFooter(l10n.settingsMoreActionsHelp),
        gap,
        GroupedList(
          children: [
            GroupedListTile(
              icon: LucideIcons.copy,
              label: l10n.settingsCopySetup,
              onTap: () => _copy(context, bar, preferences.hiddenActions),
            ),
            GroupedListTile(
              icon: LucideIcons.clipboardPaste,
              label: l10n.settingsPasteSetup,
              onTap: () => _paste(context, ref),
            ),
            GroupedListTile(
              icon: LucideIcons.rotateCcw,
              label: l10n.settingsQuickActionsReset,
              onTap: () => controller.setActions(
                bar: QuickAction.defaults,
                hidden: const {},
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _copy(
    BuildContext context,
    List<QuickAction> bar,
    Set<QuickAction> hidden,
  ) async {
    final message = context.l10n.settingsSetupCopied;
    await Clipboard.setData(
      ClipboardData(
        text: QuickActionSetup(bar: bar, hidden: hidden).encode(),
      ),
    );
    if (context.mounted) AppSnackbar.show(context, message);
  }

  Future<void> _paste(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final setup = QuickActionSetup.decode(data?.text);
    if (!context.mounted) return;
    if (setup == null) {
      AppSnackbar.show(
        context,
        l10n.settingsSetupPasteFailed,
        kind: SnackbarKind.error,
      );
      return;
    }
    await ref
        .read(editorPreferencesControllerProvider.notifier)
        .setActions(bar: setup.bar, hidden: setup.hidden);
    if (context.mounted) AppSnackbar.show(context, l10n.settingsSetupPasted);
  }
}

/// An action in More: + puts it in the bar, the switch turns it off.
class _MoreRow extends GroupedListRow {
  const _MoreRow({
    required this.action,
    required this.isOn,
    required this.canAddToBar,
    required this.onAddToBar,
    required this.onChanged,
  });

  final QuickAction action;
  final bool isOn;
  final bool canAddToBar;
  final VoidCallback onAddToBar;
  final ValueChanged<bool> onChanged;

  @override
  double get dividerStart => GroupedListTile.textStart;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (:icon, :label) = action.iconAndLabel(l10n);
    return GroupedListTile(
      icon: icon,
      label: label,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: AnchorTokens.space4,
        children: [
          BarButton(
            icon: LucideIcons.circlePlus,
            label: l10n.settingsAddToBar(label),
            size: BarButtonSize.small,
            onPressed: isOn && canAddToBar ? onAddToBar : null,
          ),
          PlatformSwitch(
            value: isOn,
            onChanged: onChanged,
            semanticLabel: label,
          ),
        ],
      ),
    );
  }
}
