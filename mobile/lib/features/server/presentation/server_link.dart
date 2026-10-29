import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/network/server_address.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/context_extensions.dart';
import '../../../core/theme/tokens/anchor_tokens.dart';
import '../../../core/widgets/pressable.dart';
import '../../../l10n/l10n.dart';

class ServerLink extends StatelessWidget {
  const ServerLink({super.key, required this.url, required this.onTap});

  final String url;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    final host = hostOf(url);
    return Pressable(
      style: PressStyle.plain,
      onTap: onTap,
      semanticLabel: context.l10n.serverLinkLabel(host),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Flexible(
            child: Text(
              host,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.row.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.appText,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            LucideIcons.chevronDown,
            size: AnchorTokens.sizeIconSmall,
            color: colors.appMuted,
          ),
        ],
      ),
    );
  }
}
