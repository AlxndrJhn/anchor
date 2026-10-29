import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../../../../l10n/app_localizations.dart';
import 'editor_format.dart';
import 'line_kind.dart';
import 'slash_menu.dart';

String textBeforeCaret(QuillController controller) {
  final found = controller.document.queryChild(controller.selection.baseOffset);
  final line = found.node;
  if (line is! Line) return '';
  final text = line.toPlainText();
  return text.substring(0, found.offset.clamp(0, text.length));
}

/// A "/" at the start of the text or after a space, and what follows it.
final _slashWord = RegExp(r'(^|\s)/([^/]*)$');

final _space = RegExp(r'\s');

/// What follows the "/" at [slashOffset] up to the caret; null when there
/// is no slash to answer.
String? slashQueryAt(
  QuillController controller, {
  required int slashOffset,
  required AppLocalizations l10n,
}) {
  final caret = controller.selection;
  if (!caret.isCollapsed || controller.lineKind == LineKind.code) return null;
  final query = _slashWord.firstMatch(textBeforeCaret(controller))?.group(2);
  if (query == null ||
      caret.baseOffset - query.length - 1 != slashOffset ||
      query.startsWith(_space) ||
      (query.contains(_space) && findSlashItems(query, l10n).isEmpty)) {
    return null;
  }
  return query;
}

final _markdownShortcut = RegExp(
  r'^\s*?(\d+[.)]|[-*+]|\[ ?\]|\[x\]|#{1,3}|>|```)$',
);

LineKind _lineKindOfShortcut(String mark) => switch (mark) {
  '#' => LineKind.h1,
  '##' => LineKind.h2,
  '###' => LineKind.h3,
  '>' => LineKind.quote,
  '```' => LineKind.code,
  _ when mark.startsWith('[') => LineKind.checklist,
  _ when mark.contains(RegExp(r'\d')) => LineKind.numbered,
  _ => LineKind.bullet,
};

extension MarkdownShortcuts on QuillController {
  /// True when it did.
  bool applyMarkdownShortcut() {
    final caret = selection;
    if (!caret.isCollapsed) return false;
    final found = document.queryChild(caret.baseOffset);
    final line = found.node;
    if (line is! Line || found.offset < 2) return false;
    final kind = lineKindOfLine(line);
    if (kind == LineKind.code || kind == LineKind.quote) return false;
    final before = line.toPlainText().substring(0, found.offset);
    if (!before.endsWith(' ') && !before.endsWith('\u00a0')) return false;
    final mark = _markdownShortcut
        .firstMatch(before.substring(0, before.length - 1))
        ?.group(1);
    if (mark == null) return false;
    final attributes = lineAttributesOf(_lineKindOfShortcut(mark));
    if (mark == '[x]') attributes[Attribute.list.key] = Attribute.checked.value;
    compose(
      Delta()
        ..retain(caret.baseOffset - found.offset)
        ..delete(found.offset)
        ..retain(line.length - 1 - found.offset)
        ..retain(1, attributes),
      selection,
      ChangeSource.local,
    );
    return true;
  }
}
