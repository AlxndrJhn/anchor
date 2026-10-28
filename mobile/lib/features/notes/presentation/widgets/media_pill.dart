import 'package:flutter/material.dart';

import '../../../../core/motion/springs.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/tokens/anchor_tokens.dart';
import '../../../../core/widgets/pressable.dart';

/// A pill button on the dark picture page: a light wash, or white for the
/// main action.
class MediaPill extends StatelessWidget {
  const MediaPill({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isProminent = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool isProminent;

  @override
  Widget build(BuildContext context) {
    final foreground = isProminent
        ? AnchorTokens.colorMediaScrim
        : AnchorTokens.colorMediaText;
    final enabled = onPressed != null;
    return Pressable(
      style: PressStyle.button,
      onTap: onPressed,
      semanticLabel: label,
      child: AnimatedOpacity(
        opacity: enabled ? 1 : DisabledOpacity.button,
        duration: context.motion(AnchorTokens.motionDurationFade),
        child: Container(
          height: AnchorTokens.sizeControlMedium,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isProminent
                ? AnchorTokens.colorMediaText
                : AnchorTokens.colorMediaControl,
            borderRadius: BorderRadius.circular(AnchorTokens.radiusPill),
          ),
          child: ExcludeSemantics(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [
                Icon(
                  icon,
                  size: AnchorTokens.sizeIconMedium,
                  color: foreground,
                ),
                Text(
                  label,
                  style: AppTypography.secondary.copyWith(
                    fontWeight: FontWeight.w600,
                    color: foreground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
