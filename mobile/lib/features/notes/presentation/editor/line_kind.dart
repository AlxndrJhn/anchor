import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../l10n/app_localizations.dart';

enum LineKind {
  text(LucideIcons.type),
  h1(LucideIcons.heading1),
  h2(LucideIcons.heading2),
  h3(LucideIcons.heading3),
  checklist(LucideIcons.listChecks, isList: true),
  bullet(LucideIcons.list, isList: true),
  numbered(LucideIcons.listOrdered, isList: true),
  quote(LucideIcons.quote),
  code(LucideIcons.code);

  const LineKind(this.icon, {this.isList = false});

  String labelIn(AppLocalizations l10n) => switch (this) {
    LineKind.text => l10n.lineText,
    LineKind.h1 => l10n.lineH1,
    LineKind.h2 => l10n.lineH2,
    LineKind.h3 => l10n.lineH3,
    LineKind.checklist => l10n.lineChecklist,
    LineKind.bullet => l10n.lineBullet,
    LineKind.numbered => l10n.lineNumbered,
    LineKind.quote => l10n.lineQuote,
    LineKind.code => l10n.lineCode,
  };

  final IconData icon;

  final bool isList;
}
