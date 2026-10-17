import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/motion/haptics.dart';
import '../../../../core/motion/pop_in.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/context_extensions.dart';
import '../../../../core/theme/tokens/anchor_tokens.dart';
import '../../../../core/widgets/anchor_menu.dart';
import '../../../../l10n/l10n.dart';
import 'line_kind.dart';

enum SlashAction { link, picture }

class SlashItem {
  const SlashItem.line(LineKind this.kind, {this.isCommon = false})
    : action = null;

  const SlashItem.action(SlashAction this.action, {this.isCommon = false})
    : kind = null;

  final LineKind? kind;
  final SlashAction? action;

  /// Shown before anything is typed after the slash.
  final bool isCommon;

  IconData get icon =>
      kind?.icon ??
      switch (action!) {
        SlashAction.link => LucideIcons.link,
        SlashAction.picture => LucideIcons.imagePlus,
      };

  String labelIn(AppLocalizations l10n) =>
      kind?.labelIn(l10n) ??
      switch (action!) {
        SlashAction.link => l10n.editorLink,
        SlashAction.picture => l10n.starterAttachment,
      };

  /// More words that find this item, besides its label.
  String wordsIn(AppLocalizations l10n) => switch ((kind, action)) {
    (LineKind.checklist, _) => l10n.slashWordsChecklist,
    (LineKind.h1, _) => l10n.slashWordsH1,
    (LineKind.h2, _) => l10n.slashWordsH2,
    (LineKind.h3, _) => l10n.slashWordsH3,
    (LineKind.bullet, _) => l10n.slashWordsBullet,
    (LineKind.numbered, _) => l10n.slashWordsNumbered,
    (LineKind.quote, _) => l10n.slashWordsQuote,
    (LineKind.code, _) => l10n.slashWordsCode,
    (LineKind.text, _) => l10n.slashWordsText,
    (_, SlashAction.link) => l10n.slashWordsLink,
    (_, SlashAction.picture) => l10n.slashWordsAttachment,
    _ => '',
  };
}

const List<SlashItem> slashItems = [
  SlashItem.line(LineKind.checklist, isCommon: true),
  SlashItem.line(LineKind.h1, isCommon: true),
  SlashItem.line(LineKind.h2),
  SlashItem.line(LineKind.h3),
  SlashItem.line(LineKind.bullet, isCommon: true),
  SlashItem.line(LineKind.numbered, isCommon: true),
  SlashItem.line(LineKind.quote, isCommon: true),
  SlashItem.line(LineKind.code),
  SlashItem.line(LineKind.text),
  SlashItem.action(SlashAction.link),
  SlashItem.action(SlashAction.picture, isCommon: true),
];

/// Labels starting with the query first, then labels whose words start with
/// the typed words, then the other words.
List<SlashItem> findSlashItems(String query, AppLocalizations l10n) {
  final words = query
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return slashItems.where((s) => s.isCommon).toList();
  final joined = words.join();
  final ranked = <(SlashItem, int, int)>[];
  for (var i = 0; i < slashItems.length; i++) {
    final item = slashItems[i];
    final label = item.labelIn(l10n).toLowerCase();
    final own = label.split(' ');
    final all = [...own, ...item.wordsIn(l10n).toLowerCase().split(' ')];
    bool starts(List<String> list) =>
        words.every((w) => list.any((x) => x.startsWith(w)));
    final rank = label.replaceAll(' ', '').startsWith(joined)
        ? 0
        : starts(own)
        ? 1
        : starts(all)
        ? 2
        : -1;
    if (rank >= 0) ranked.add((item, rank, i));
  }
  ranked.sort((a, b) => a.$2 != b.$2 ? a.$2 - b.$2 : a.$3 - b.$3);
  return ranked.map((r) => r.$1).toList();
}

class SlashMenu extends StatelessWidget {
  const SlashMenu({
    super.key,
    required this.items,
    required this.onPick,
    required this.space,
  });

  static const double caretGap = AnchorTokens.space8;

  static const double minSpace =
      2 * AnchorTokens.sizeControlMedium + 2 * MenuPanel.padding;

  final List<SlashItem> items;
  final ValueChanged<SlashItem> onPick;

  final double space;

  static double heightFor(int rowCount, double space) {
    const row = AnchorTokens.sizeControlMedium;
    const padding = 2 * MenuPanel.padding;
    final available = math.max(space, minSpace) - padding;
    if (rowCount * row <= available) return rowCount * row + padding;
    final wholeRows = math.max(1, ((available - row / 2) / row).floor());
    return wholeRows * row + row / 2 + padding;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    return PopIn(
      alignment: Alignment.bottomLeft,
      child: Semantics(
        container: true,
        label: context.l10n.slashMenuLabel,
        child: MenuPanel(
          width: 250, // off-scale: the menu's width
          maxHeight: items.isEmpty ? null : heightFor(items.length, space),
          child: items.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 12,
                  ),
                  child: Text(
                    context.l10n.slashNoResults,
                    style: AppTypography.secondary.copyWith(
                      color: colors.appMuted,
                    ),
                  ),
                )
              : ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  children: [
                    for (var i = 0; i < items.length; i++)
                      MenuRow(
                        icon: items[i].icon,
                        label: items[i].labelIn(context.l10n),
                        isHighlighted: i == 0,
                        onPressed: () {
                          Haptics.selection();
                          onPick(items[i]);
                        },
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}
