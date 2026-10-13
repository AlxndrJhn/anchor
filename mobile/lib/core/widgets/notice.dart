import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_typography.dart';
import '../theme/context_extensions.dart';
import '../theme/tokens/anchor_tokens.dart';
import 'pressable.dart';

enum NoticeKind { neutral, warn, danger }

class Notice extends StatelessWidget {
  const Notice({
    super.key,
    required this.text,
    this.title,
    this.icon,
    this.kind = NoticeKind.neutral,
    this.onTap,
    this.action,
  });

  final String text;

  final String? title;
  final IconData? icon;
  final NoticeKind kind;
  final VoidCallback? onTap;
  final Widget? action;

  static final _line = AppTypography.secondary;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    final (fill, iconColor, textColor) = switch (kind) {
      NoticeKind.neutral => (
        colors.appText.withValues(alpha: 0.06),
        colors.appMuted,
        colors.appText,
      ),
      NoticeKind.warn => (
        colors.statusWarnFill,
        colors.statusWarnText,
        colors.statusWarnText,
      ),
      NoticeKind.danger => (
        Color.alphaBlend(
          colors.statusDanger.withValues(alpha: 0.11),
          colors.appSurface,
        ),
        colors.statusDanger,
        colors.appText,
      ),
    };
    final words = Text.rich(
      TextSpan(
        children: [
          if (title != null)
            TextSpan(
              text: '$title ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          TextSpan(text: text),
        ],
      ),
      style: _line.copyWith(color: textColor),
    );
    final lineHeight = _line.fontSize! * _line.height!;
    final box = Container(
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: context.density.space12,
      ),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AnchorTokens.radius2xl),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          if (icon != null)
            SizedBox(
              height: lineHeight,
              child: Icon(
                icon,
                size: AnchorTokens.sizeIconMedium,
                color: iconColor,
              ),
            ),
          Expanded(
            child: action == null
                ? words
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 12,
                    children: [words, action!],
                  ),
          ),
          if (onTap != null)
            SizedBox(
              height: lineHeight,
              child: Icon(
                LucideIcons.chevronRight,
                size: AnchorTokens.sizeIconSmall,
                color: iconColor.withValues(alpha: 0.8),
              ),
            ),
        ],
      ),
    );
    if (onTap != null) {
      return Pressable(
        style: PressStyle.button,
        onTap: onTap,
        semanticLabel: title == null ? text : '$title $text',
        child: box,
      );
    }
    return Semantics(
      container: true,
      liveRegion: kind == NoticeKind.danger,
      child: box,
    );
  }
}
