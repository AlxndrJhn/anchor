import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/l10n.dart';
import '../theme/context_extensions.dart';
import '../theme/tokens/anchor_tokens.dart';
import 'app_buttons.dart';
import 'pressable.dart';

enum PlayButtonSize {
  regular(AnchorTokens.sizeControlSmall, 14), // off-scale: play glyph
  large(AnchorTokens.space48, AnchorTokens.sizeIconMedium);

  const PlayButtonSize(this.box, this.icon);

  final double box;
  final double icon;
}

class PlayButton extends StatelessWidget {
  const PlayButton({
    super.key,
    required this.isPlaying,
    required this.onPressed,
    this.name,
    this.isLoading = false,
    this.size = PlayButtonSize.regular,
    this.iconColor,
  });

  final bool isPlaying;
  final VoidCallback? onPressed;

  final String? name;

  final bool isLoading;
  final PlayButtonSize size;

  /// The icon's color.
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    final color = iconColor ?? colors.appSurface;
    final l10n = context.l10n;
    final label = switch ((isPlaying, name)) {
      (true, final name?) => l10n.commonPauseItem(name),
      (true, null) => l10n.commonPause,
      (false, final name?) => l10n.commonPlayItem(name),
      (false, null) => l10n.commonPlay,
    };
    return Pressable(
      style: PressStyle.button,
      onTap: isLoading ? null : onPressed,
      semanticLabel: label,
      child: Container(
        width: size.box,
        height: size.box,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.appText,
          shape: BoxShape.circle,
        ),
        child: isLoading
            ? Spinner(size: size.icon, color: color)
            : Icon(
                isPlaying ? LucideIcons.pause : LucideIcons.play,
                size: size.icon,
                color: color,
              ),
      ),
    );
  }
}
