import 'package:flutter/material.dart';

import '../theme/app_typography.dart';
import '../theme/context_extensions.dart';
import '../theme/tokens/anchor_tokens.dart';
import 'anchor_logo.dart';
import 'expanded_hit_area.dart';

class PageHeading extends StatelessWidget {
  const PageHeading({
    super.key,
    required this.title,
    required this.subtitle,
    this.subtitleLink,
    this.hasIcon = false,
    this.isCentered = false,
  });

  /// Marks where [subtitleLink] goes in [subtitle].
  static const linkSlot = '\u{FFFC}';

  final String title;
  final String subtitle;

  /// Takes the place of [linkSlot] in [subtitle], or follows it.
  final Widget? subtitleLink;

  final bool hasIcon;
  final bool isCentered;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    final align = isCentered ? TextAlign.center : TextAlign.start;
    final subtitleStyle = AppTypography.row.copyWith(
      height: 1.45,
      color: colors.appMuted,
    );
    const hitPadding = AnchorTokens.space12;
    final link = subtitleLink;
    final slot = subtitle.indexOf(linkSlot);
    final before = slot < 0 ? '$subtitle ' : subtitle.substring(0, slot);
    final after = slot < 0 ? '' : subtitle.substring(slot + linkSlot.length);
    final heading = Column(
      crossAxisAlignment: isCentered
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        if (hasIcon) ...[
          const AnchorLogo(size: AnchorLogo.heading),
          SizedBox(height: context.density.space16),
        ],
        Semantics(
          header: true,
          child: Text(
            title,
            textAlign: align,
            style: AppTypography.largeTitle.copyWith(color: colors.appText),
          ),
        ),
        const SizedBox(height: 4),
        if (link == null)
          Text(subtitle, textAlign: align, style: subtitleStyle)
        else
          ExpandedHitArea(
            padding: EdgeInsets.symmetric(vertical: hitPadding),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                if (before.isNotEmpty) Text(before, style: subtitleStyle),
                Flexible(child: link),
                if (after.isNotEmpty) Text(after, style: subtitleStyle),
              ],
            ),
          ),
      ],
    );
    if (link == null) return heading;
    return ExpandedHitArea(
      padding: EdgeInsets.only(bottom: hitPadding),
      child: heading,
    );
  }
}
