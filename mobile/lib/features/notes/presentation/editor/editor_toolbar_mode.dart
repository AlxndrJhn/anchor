import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../l10n/app_localizations.dart';
import 'line_kind.dart';

enum EditorSubmenu { none, styles, colors }

enum EditorToolbarMode {
  typing,
  list,
  selected,
  styles,
  colors;

  String labelIn(AppLocalizations l10n) => switch (this) {
    EditorToolbarMode.typing => l10n.barFormatting,
    EditorToolbarMode.list => l10n.barList,
    EditorToolbarMode.selected => l10n.barSelected,
    EditorToolbarMode.styles => l10n.barStyles,
    EditorToolbarMode.colors => l10n.barColors,
  };
}

enum EditorTool {
  styles(LucideIcons.aLargeSmall),
  back(LucideIcons.chevronLeft),
  checklist(LucideIcons.listChecks),
  bullet(LucideIcons.list),
  add(LucideIcons.imagePlus),
  outdent(LucideIcons.indentDecrease),
  indent(LucideIcons.indentIncrease),
  bold(LucideIcons.bold),
  italic(LucideIcons.italic),
  underline(LucideIcons.underline),
  strikethrough(LucideIcons.strikethrough),
  highlight(LucideIcons.highlighter),
  link(LucideIcons.link),
  yellow(null, highlightName: 'yellow'),
  green(null, highlightName: 'green'),
  blue(null, highlightName: 'blue'),
  pink(null, highlightName: 'pink'),
  purple(null, highlightName: 'purple'),
  removeHighlight(LucideIcons.eraser),
  undo(LucideIcons.undo2),
  redo(LucideIcons.redo2),
  hideKeyboard(LucideIcons.keyboardOff);

  const EditorTool(this.icon, {this.highlightName});

  /// Null for a highlight color.
  final IconData? icon;
  final String? highlightName;

  String labelIn(AppLocalizations l10n) => switch (this) {
    EditorTool.styles => l10n.barStyles,
    EditorTool.back => l10n.commonBack,
    EditorTool.checklist => l10n.lineChecklist,
    EditorTool.bullet => l10n.lineBullet,
    EditorTool.add => l10n.attachmentAddLabel,
    EditorTool.outdent => l10n.toolOutdent,
    EditorTool.indent => l10n.toolIndent,
    EditorTool.bold => l10n.toolBold,
    EditorTool.italic => l10n.toolItalic,
    EditorTool.underline => l10n.toolUnderline,
    EditorTool.strikethrough => l10n.toolStrikethrough,
    EditorTool.highlight => l10n.toolHighlight,
    EditorTool.link => l10n.editorLink,
    EditorTool.yellow => l10n.colorYellow,
    EditorTool.green => l10n.colorGreen,
    EditorTool.blue => l10n.colorBlue,
    EditorTool.pink => l10n.colorPink,
    EditorTool.purple => l10n.colorPurple,
    EditorTool.removeHighlight => l10n.toolRemoveHighlight,
    EditorTool.undo => l10n.commonUndo,
    EditorTool.redo => l10n.toolRedo,
    EditorTool.hideKeyboard => l10n.toolHideKeyboard,
  };

  static const List<EditorTool> inline = [
    bold,
    italic,
    underline,
    strikethrough,
  ];

  static const List<EditorTool> colors = [yellow, green, blue, pink, purple];
}

const List<LineKind> lineStyles = [
  LineKind.h1,
  LineKind.h2,
  LineKind.h3,
  LineKind.checklist,
  LineKind.bullet,
  LineKind.numbered,
  LineKind.quote,
  LineKind.code,
];

/// [hasWords] means words are selected in the text, not in the title.
EditorToolbarMode toolbarModeOf({
  required bool isInTitle,
  required bool hasWords,
  required LineKind lineKind,
  required EditorSubmenu submenu,
}) {
  switch (submenu) {
    case EditorSubmenu.styles:
      return EditorToolbarMode.styles;
    case EditorSubmenu.colors:
      return EditorToolbarMode.colors;
    case EditorSubmenu.none:
      break;
  }
  if (isInTitle) return EditorToolbarMode.typing;
  if (hasWords && lineKind != LineKind.code) return EditorToolbarMode.selected;
  return lineKind.isList ? EditorToolbarMode.list : EditorToolbarMode.typing;
}

({List<EditorTool> start, List<EditorTool> end}) toolbarToolsOf(
  EditorToolbarMode mode, {
  bool isInCode = false,
  bool hasWords = false,
}) {
  final start = switch (mode) {
    EditorToolbarMode.typing => const [
      EditorTool.styles,
      EditorTool.checklist,
      EditorTool.bullet,
      EditorTool.add,
    ],
    EditorToolbarMode.list => const [
      EditorTool.styles,
      EditorTool.checklist,
      EditorTool.bullet,
      EditorTool.outdent,
      EditorTool.indent,
    ],
    EditorToolbarMode.selected => const [
      EditorTool.styles,
      ...EditorTool.inline,
      EditorTool.highlight,
      EditorTool.link,
    ],
    EditorToolbarMode.styles => [
      EditorTool.styles,
      if (!isInCode) ...EditorTool.inline,
      if (!isInCode && hasWords) ...[EditorTool.highlight, EditorTool.link],
    ],
    EditorToolbarMode.colors => const [
      EditorTool.back,
      ...EditorTool.colors,
      EditorTool.removeHighlight,
    ],
  };
  final hasHistory =
      mode == EditorToolbarMode.typing || mode == EditorToolbarMode.list;
  return (
    start: start,
    end: [
      if (hasHistory) ...[EditorTool.undo, EditorTool.redo],
      EditorTool.hideKeyboard,
    ],
  );
}

@immutable
class EditorToolbarModel {
  const EditorToolbarModel({
    required this.mode,
    required this.start,
    required this.end,
    this.activeTools = const {},
    this.disabledTools = const {},
    this.lineKind = LineKind.text,
    this.highlightName = 'yellow',
  });

  factory EditorToolbarModel.of({
    required bool isInTitle,
    required bool hasWords,
    required LineKind lineKind,
    required EditorSubmenu submenu,
    Set<EditorTool> formats = const {},
    String? highlight,
    required String lastHighlight,
    required bool canUndo,
    required bool canRedo,
  }) {
    final mode = toolbarModeOf(
      isInTitle: isInTitle,
      hasWords: hasWords,
      lineKind: lineKind,
      submenu: submenu,
    );
    final kind = isInTitle ? LineKind.text : lineKind;
    final tools = toolbarToolsOf(
      mode,
      isInCode: kind == LineKind.code,
      hasWords: hasWords,
    );
    return EditorToolbarModel(
      mode: mode,
      start: tools.start,
      end: tools.end,
      lineKind: kind,
      highlightName: highlight ?? lastHighlight,
      activeTools: {
        if (submenu == EditorSubmenu.styles) EditorTool.styles,
        if (kind == LineKind.checklist) EditorTool.checklist,
        if (kind == LineKind.bullet) EditorTool.bullet,
        ...formats.where(EditorTool.inline.contains),
        if (highlight != null) ...[
          EditorTool.highlight,
          ?EditorTool.colors
              .where((tool) => tool.highlightName == highlight)
              .firstOrNull,
        ],
      },
      disabledTools: {
        if (isInTitle) EditorTool.styles,
        if (!canUndo) EditorTool.undo,
        if (!canRedo) EditorTool.redo,
      },
    );
  }

  final EditorToolbarMode mode;
  final List<EditorTool> start;
  final List<EditorTool> end;

  final Set<EditorTool> activeTools;

  final Set<EditorTool> disabledTools;

  final LineKind lineKind;

  final String highlightName;

  bool get hasLineStyles => mode == EditorToolbarMode.styles;

  int get rows => hasLineStyles ? 2 : 1;

  @override
  bool operator ==(Object other) =>
      other is EditorToolbarModel &&
      other.mode == mode &&
      listEquals(other.start, start) &&
      listEquals(other.end, end) &&
      setEquals(other.activeTools, activeTools) &&
      setEquals(other.disabledTools, disabledTools) &&
      other.lineKind == lineKind &&
      other.highlightName == highlightName;

  @override
  int get hashCode => Object.hash(
    mode,
    Object.hashAll(start),
    Object.hashAll(end),
    Object.hashAllUnordered(activeTools),
    Object.hashAllUnordered(disabledTools),
    lineKind,
    highlightName,
  );
}
