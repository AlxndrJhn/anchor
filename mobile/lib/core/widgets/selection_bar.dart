import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../motion/springs.dart';
import '../theme/app_typography.dart';
import '../theme/context_extensions.dart';
import '../theme/tokens/anchor_tokens.dart';
import 'frosted_glass.dart';
import 'pressable.dart';

class SelectionAction {
  const SelectionAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isDanger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool isDanger;
}

class SelectionBar extends StatelessWidget {
  const SelectionBar({
    super.key,
    required this.actions,
    required this.enabled,
    this.label,
  });

  final List<SelectionAction> actions;
  final bool enabled;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    return Semantics(
      container: true,
      label: label ?? context.l10n.commonSelectedNotes,
      child: FrostedGlass(
        child: Container(
          height: context.density.control + context.density.space12,
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              for (final action in actions)
                Expanded(
                  child: Pressable(
                    style: PressStyle.toolbar,
                    onTap: enabled ? action.onPressed : null,
                    semanticLabel: action.label,
                    child: AnimatedOpacity(
                      opacity: enabled ? 1 : DisabledOpacity.button,
                      duration: context.motion(AnchorTokens.motionDurationFade),
                      // In Compact the icon and label are a hair taller than the bar's space.
                      child: OverflowBox(
                        maxHeight: double.infinity,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          spacing: 4,
                          children: [
                            Icon(
                              action.icon,
                              size: AnchorTokens.sizeIconLarge,
                              color: action.isDanger
                                  ? colors.statusDanger
                                  : colors.appText,
                            ),
                            Text(
                              action.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.footnote.copyWith(
                                color: colors.appText,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Keep both built: the bottom bar holds its search text.
class SelectionBarSwitcher extends StatelessWidget {
  const SelectionBarSwitcher({
    super.key,
    required this.isSelecting,
    required this.bottomBar,
    required this.selectionBar,
  });

  final bool isSelecting;
  final Widget bottomBar;
  final Widget selectionBar;

  @override
  Widget build(BuildContext context) {
    Widget part(Widget child, bool isShown) => Align(
      alignment: Alignment.bottomCenter,
      heightFactor: isShown ? 1 : 0,
      child: AnimatedSlide(
        offset: isShown ? Offset.zero : const Offset(0, 1.4),
        duration: context.motion(Spring.snappy.duration),
        curve: Spring.snappy.curve,
        child: AnimatedOpacity(
          opacity: isShown ? 1 : 0,
          duration: context.motion(
            isShown
                ? AnchorTokens.motionDurationHover
                : AnchorTokens.motionDurationExit,
          ),
          child: IgnorePointer(ignoring: !isShown, child: child),
        ),
      ),
    );
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        part(bottomBar, !isSelecting),
        part(selectionBar, isSelecting),
      ],
    );
  }
}
