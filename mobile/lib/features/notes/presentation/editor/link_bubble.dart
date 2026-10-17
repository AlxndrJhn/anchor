import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/motion/pop_in.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/context_extensions.dart';
import '../../../../core/theme/tokens/anchor_tokens.dart';
import '../../../../core/widgets/anchor_menu.dart';
import '../../../../core/widgets/page_bar.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../l10n/l10n.dart';
import 'editor_link.dart';

class LinkBubble extends StatelessWidget {
  const LinkBubble({
    super.key,
    required this.link,
    required this.canEdit,
    required this.onClose,
    required this.onOpen,
    required this.onCopy,
    required this.onEdit,
    required this.onRemove,
  });

  final EditorLink link;
  final bool canEdit;
  final VoidCallback onClose;
  final VoidCallback onOpen;
  final VoidCallback onCopy;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    final width = MediaQuery.sizeOf(context).width;
    final top = MediaQuery.paddingOf(context).top + PageBar.heightOf(context);
    final above = link.rect.top - 100 > top;
    final left = (link.rect.left - 8)
        .clamp(16.0, math.max(16.0, width - 316))
        .toDouble();
    Widget action(
      IconData icon,
      String label,
      VoidCallback onTap, {
      bool isDanger = false,
    }) {
      final color = isDanger ? colors.statusDanger : colors.appText;
      return Pressable(
        style: PressStyle.menuItem,
        onTap: () {
          onClose();
          onTap();
        },
        semanticLabel: label,
        tintRadius: BorderRadius.circular(AnchorTokens.radiusLg),
        child: Container(
          height: AnchorTokens.sizeControlMedium,
          constraints: const BoxConstraints(
            minWidth: AnchorTokens.sizeControlMedium,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 8,
            children: [
              Icon(icon, size: AnchorTokens.sizeIconMedium, color: color),
              if (!canEdit)
                Text(
                  label,
                  style: AppTypography.secondary.copyWith(color: color),
                ),
            ],
          ),
        ),
      );
    }

    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: onClose,
        child: Stack(
          children: [
            Positioned(
              left: left,
              top: above ? null : link.rect.bottom + 8,
              bottom: above
                  ? MediaQuery.sizeOf(context).height - link.rect.top + 8
                  : null,
              child: PopIn(
                alignment: above ? Alignment.bottomLeft : Alignment.topLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 300, // off-scale: the bubble's widest
                  ),
                  child: MenuPanel(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 8,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            spacing: 8,
                            children: [
                              Icon(
                                LucideIcons.link,
                                size: AnchorTokens.sizeIconSmall,
                                color: colors.appMuted,
                              ),
                              Flexible(
                                child: Text(
                                  link.url,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.footnote.copyWith(
                                    color: colors.appMuted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          spacing: 4,
                          children: [
                            action(
                              LucideIcons.externalLink,
                              context.l10n.commonOpen,
                              onOpen,
                            ),
                            action(
                              LucideIcons.copy,
                              context.l10n.commonCopy,
                              onCopy,
                            ),
                            if (canEdit)
                              action(
                                LucideIcons.pencil,
                                context.l10n.commonEdit,
                                onEdit,
                              ),
                            if (canEdit)
                              action(
                                LucideIcons.unlink,
                                context.l10n.commonRemove,
                                onRemove,
                                isDanger: true,
                              ),
                          ],
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
    );
  }
}
