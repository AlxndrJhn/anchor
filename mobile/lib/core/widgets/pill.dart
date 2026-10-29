import 'package:flutter/material.dart';

import '../motion/springs.dart';
import '../theme/app_typography.dart';
import '../theme/context_extensions.dart';
import '../theme/tokens/anchor_tokens.dart';
import 'pressable.dart';

enum PillKind { neutral, warn, outlined }

typedef PillColors = ({Color edge, Color muted});

class Pill extends StatelessWidget {
  const Pill({
    super.key,
    required this.label,
    this.icon,
    this.trailingIcon,
    this.kind = PillKind.neutral,
    this.isOn = false,
    this.colors,
    this.iconColor,
  });

  final String label;
  final IconData? icon;

  /// While off.
  final Color? iconColor;

  final IconData? trailingIcon;
  final PillKind kind;

  final bool isOn;

  /// Used by [PillKind.outlined].
  final PillColors? colors;

  @override
  Widget build(BuildContext context) {
    final themeColors = context.anchor;
    final outline =
        colors ?? (edge: themeColors.appBorder, muted: themeColors.appMuted);
    final (fill, textColor, muted) = isOn
        ? (themeColors.appText, themeColors.appSurface, themeColors.appSurface)
        : switch (kind) {
            PillKind.neutral => (
              themeColors.appText.withValues(alpha: 0.07),
              themeColors.appText,
              themeColors.appMuted,
            ),
            PillKind.warn => (
              themeColors.statusWarnFill,
              themeColors.statusWarnText,
              themeColors.statusWarnText,
            ),
            PillKind.outlined => (
              Colors.transparent,
              themeColors.appText,
              outline.muted,
            ),
          };
    return AnimatedContainer(
      duration: context.motion(AnchorTokens.motionDurationHover),
      constraints: const BoxConstraints(
        minHeight: AnchorTokens.sizeControlSmall,
      ),
      padding: EdgeInsets.only(left: 12, right: trailingIcon == null ? 12 : 8),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AnchorTokens.radiusPill),
      ),
      foregroundDecoration: kind == PillKind.outlined && !isOn
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(AnchorTokens.radiusPill),
              border: Border.all(color: outline.edge.withValues(alpha: 0.85)),
            )
          : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: AnchorTokens.sizeIconSmall,
              color: isOn ? muted : iconColor ?? muted,
            ),
            const SizedBox(width: AnchorTokens.space8),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.secondary.tabular.copyWith(
                fontWeight: isOn ? FontWeight.w600 : FontWeight.w400,
                color: textColor,
              ),
            ),
          ),
          if (trailingIcon != null) ...[
            const SizedBox(width: AnchorTokens.space4),
            Icon(trailingIcon, size: AnchorTokens.sizeIconSmall, color: muted),
          ],
        ],
      ),
    );
  }
}

class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.trailingIcon,
    this.kind = PillKind.neutral,
    this.isOn,
    this.colors,
    this.iconColor,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// While off.
  final Color? iconColor;
  final IconData? trailingIcon;
  final PillKind kind;
  final bool? isOn;
  final PillColors? colors;

  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      style: PressStyle.button,
      onTap: onPressed,
      semanticLabel: semanticLabel ?? label,
      toggled: isOn,
      child: AnimatedOpacity(
        opacity: onPressed == null ? DisabledOpacity.button : 1,
        duration: context.motion(AnchorTokens.motionDurationFade),
        child: Pill(
          label: label,
          icon: icon,
          iconColor: iconColor,
          trailingIcon: trailingIcon,
          kind: kind,
          isOn: isOn ?? false,
          colors: colors,
        ),
      ),
    );
  }
}
