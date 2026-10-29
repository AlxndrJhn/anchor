import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../../../../core/links/link_utils.dart';
import 'editor_format.dart';
import 'line_kind.dart';

class EditorLink {
  const EditorLink({
    required this.url,
    required this.start,
    required this.length,
    required this.rect,
  });

  final String url;
  final int start;
  final int length;

  /// In global coordinates.
  final Rect rect;

  TextRange get range => TextRange(start: start, end: start + length);
}

extension LinkEditing on QuillController {
  void insertLink(int offset, String text, String url) {
    replaceText(
      offset,
      0,
      text,
      TextSelection.collapsed(offset: offset + text.length),
    );
    formatText(offset, text.length, LinkAttribute(url));
  }

  void replaceWithLink(int start, int length, String text, String url) {
    replaceText(start, length, '', null);
    insertLink(start, text, url);
  }

  /// False when the clipboard isn't a whole address; Quill then pastes as
  /// usual.
  Future<bool> pasteAddressAsLink() async {
    final clip = await Clipboard.getData(Clipboard.kTextPlain);
    final raw = clip?.text?.trim() ?? '';
    if (!isFullUrl(raw)) return false;
    final currentSelection = selection;
    if (!currentSelection.isValid || lineKind == LineKind.code) return false;
    final url = normalizeUrl(raw);
    if (currentSelection.isCollapsed) {
      insertLink(currentSelection.start, raw, url);
    } else {
      formatText(
        currentSelection.start,
        currentSelection.end - currentSelection.start,
        LinkAttribute(url),
      );
      updateSelection(
        TextSelection.collapsed(offset: currentSelection.end),
        ChangeSource.local,
      );
    }
    return true;
  }

  /// True when it linked.
  bool linkTypedAddress(int end) {
    final found = document.queryChild(end);
    final line = found.node;
    if (line is! Line || lineKindOfLine(line) == LineKind.code) return false;
    final text = line.toPlainText().substring(0, found.offset);
    final word = _lastWord(text);
    if (word == null) return false;
    final url = linkForTypedAddress(word.text);
    if (url == null || _hasLink(line, word.start, word.text.length)) {
      return false;
    }
    compose(
      Delta()
        ..retain(end - found.offset + word.start)
        ..retain(word.text.length, LinkAttribute(url).toJson()),
      selection,
      ChangeSource.local,
    );
    return true;
  }

  void removeLinkAt(int start, int length) =>
      formatText(start, length, Attribute.clone(Attribute.link, null));

  EditorLink? linkAt(int offset, RenderEditor editor) {
    if (offset >= document.length - 1) return null;
    final leaf = document.querySegmentLeafNode(offset).leaf;
    final url = leaf?.style.attributes[Attribute.link.key]?.value;
    if (leaf == null || url is! String) return null;
    // Neighboring runs on the line with the same address are one link.
    final range = getLinkRange(leaf);
    final startRect = editor.getLocalRectForCaret(
      TextPosition(offset: range.start),
    );
    final endRect = editor.getLocalRectForCaret(
      TextPosition(offset: range.end, affinity: TextAffinity.upstream),
    );
    final topLeft = editor.localToGlobal(Offset(startRect.left, startRect.top));
    final sameLine = (endRect.top - startRect.top).abs() < 2;
    final bottomRight = editor.localToGlobal(
      Offset(sameLine ? endRect.left : startRect.left + 80, startRect.bottom),
    );
    return EditorLink(
      url: url,
      start: range.start,
      length: range.end - range.start,
      rect: Rect.fromPoints(topLeft, bottomRight),
    );
  }
}

final _lastRun = RegExp(r'\S+$');

({int start, String text})? _lastWord(String text) {
  final match = _lastRun.firstMatch(text);
  if (match == null) return null;
  final word = wordIn(match[0]!);
  return word == null
      ? null
      : (start: match.start + word.start, text: word.text);
}

bool _hasLink(Line line, int start, int length) {
  for (final leaf in line.children) {
    if (leaf.offset + leaf.length <= start) continue;
    if (leaf.offset >= start + length) break;
    if (leaf.style.attributes.containsKey(Attribute.link.key)) return true;
  }
  return false;
}
