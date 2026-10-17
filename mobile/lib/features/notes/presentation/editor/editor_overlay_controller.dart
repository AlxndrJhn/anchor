import 'package:flutter/widgets.dart';

import '../../../../core/theme/tokens/anchor_tokens.dart';
import 'editor_format.dart';
import 'editor_link.dart';
import 'editor_toolbar.dart';
import 'editor_toolbar_mode.dart';
import 'line_kind.dart';
import 'rich_text_editor.dart';
import 'slash_menu.dart';

class EditorOverlayController extends ChangeNotifier {
  EditorOverlayController(this._editorKey);

  final GlobalKey<RichTextEditorState> _editorKey;

  EditorSubmenu _submenu = EditorSubmenu.none;
  TextSelection? _submenuSelection;
  EditorLink? _link;
  String _highlight = 'yellow';

  RichTextEditorState? get editor => _editorKey.currentState;

  EditorSubmenu get submenu => _submenu;

  /// The link whose bubble is showing.
  EditorLink? get link => _link;

  String get highlight => _highlight;

  double get barHeight =>
      EditorToolbar.heightOf(_submenu == EditorSubmenu.styles ? 2 : 1);

  double get caretSpace => barHeight + AnchorTokens.space12;

  double get slashMenuSpace =>
      barHeight + AnchorTokens.space8 + SlashMenu.minSpace + SlashMenu.caretGap;

  void toggleStyles() => _openSubmenu(
    _submenu == EditorSubmenu.styles
        ? EditorSubmenu.none
        : EditorSubmenu.styles,
  );

  void closeSubmenu() => _openSubmenu(EditorSubmenu.none);

  void _openSubmenu(EditorSubmenu submenu) {
    if (submenu == _submenu) return;
    _submenu = submenu;
    _submenuSelection = submenu == EditorSubmenu.none
        ? null
        : editor?.selection;
    notifyListeners();
  }

  void selectionMoved(TextSelection selection) {
    if (_submenu != EditorSubmenu.none && selection != _submenuSelection) {
      closeSubmenu();
    }
  }

  void applyLineStyle(LineKind kind) {
    editor?.applyLineStyle(kind);
    closeSubmenu();
  }

  void useHighlight() {
    final editor = this.editor;
    if (editor == null || !editor.hasSelection) return;
    if (editor.controller.highlight != null) {
      _openSubmenu(EditorSubmenu.colors);
    } else {
      editor.paintHighlight(_highlight);
    }
  }

  void pickHighlight(String name) {
    _highlight = name;
    editor?.paintHighlight(name);
    if (_submenu == EditorSubmenu.none) {
      notifyListeners();
    } else {
      closeSubmenu();
    }
  }

  void removeHighlight() {
    editor?.clearHighlight();
    closeSubmenu();
  }

  void showLink(EditorLink link) {
    _link = link;
    notifyListeners();
  }

  void closeLink() {
    if (_link == null) return;
    _link = null;
    notifyListeners();
  }
}
