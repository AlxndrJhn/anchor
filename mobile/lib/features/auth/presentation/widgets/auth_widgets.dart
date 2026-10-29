import 'package:flutter/material.dart';

import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/context_extensions.dart';
import '../../../../core/theme/tokens/anchor_tokens.dart';
import '../../../../core/widgets/expanded_hit_area.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../l10n/l10n.dart';

class OrDivider extends StatelessWidget {
  const OrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    Widget line() => Expanded(
      child: Container(
        height: 1,
        color: colors.appBorder.withValues(alpha: 0.9),
      ),
    );
    return Row(
      spacing: 12,
      children: [
        line(),
        Text(
          context.l10n.authOr,
          style: AppTypography.secondary.copyWith(color: colors.appMuted),
        ),
        line(),
      ],
    );
  }
}

class AuthSwitchLink extends StatelessWidget {
  const AuthSwitchLink({
    super.key,
    required this.text,
    required this.action,
    required this.onTap,
  });

  final String text;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    return Padding(
      padding: const EdgeInsets.only(top: AnchorTokens.space4),
      child: ExpandedHitArea(
        padding: const EdgeInsets.symmetric(vertical: AnchorTokens.space12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$text ',
              style: AppTypography.secondary.copyWith(color: colors.appMuted),
            ),
            Pressable(
              style: PressStyle.plain,
              onTap: onTap,
              semanticLabel: action,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AnchorTokens.space4,
                ),
                child: Text(
                  action,
                  style: AppTypography.secondary.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.accentInk,
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
