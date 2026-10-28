import 'dart:async';
import 'dart:convert';

import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
// Reads pictures from the clipboard; flutter_quill exports it for this.
// ignore: experimental_member_use
import 'package:flutter_quill/internal.dart' show ClipboardServiceProvider;
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../search/search_pattern.dart';
import '../theme/context_extensions.dart';
import '../theme/tokens/app_durations.dart';
import '../theme/tokens/app_icon_sizes.dart';
import 'app_snackbar.dart';
import 'editor/checklist_drag_mixin.dart';
import 'editor/checklist_lines.dart';
import 'editor/checklist_reorder_mixin.dart';
import 'editor/editor_styles.dart';
import 'editor/editor_toolbar.dart';
import 'editor/link_actions_sheet.dart';
import 'editor/link_edit_sheet.dart';
import 'editor/link_utils.dart';

/// Picture types the keyboard may insert, which upload as attachments.
const insertableImageTypes = <String>[
  'image/png',
  'image/jpeg',
  'image/gif',
  'image/webp',
];

/// A reusable rich text editor widget powered by flutter_quill.
///
/// Content is stored and loaded as JSON Delta format.
class RichTextEditor extends StatefulWidget {
  /// Initial content in JSON Delta format.
  final String? initialContent;

  /// Callback when the document changes. Selection-only changes don't fire;
  /// read the content with [RichTextEditorState.getContent].
  final VoidCallback? onChanged;

  /// Callback when editing state changes (focus gained/lost).
  final ValueChanged<bool>? onEditingChanged;

  /// Hint text shown when editor is empty.
  final String hintText;

  /// Whether to show the toolbar.
  final bool showToolbar;

  /// Whether the editor can be edited.
  final bool canEdit;

  /// Focus node for the editor.
  final FocusNode? focusNode;

  /// Padding for the editor content.
  final EdgeInsets contentPadding;

  /// Whether to sort checklist items (checked to bottom, unchecked to top).
  final bool sortChecklistItems;

  /// Optional header widget placed above the editor, scrolling together.
  final Widget? header;

  /// Called with a picture the keyboard inserts (for example a screenshot
  /// pasted from Gboard's clipboard), or pasted with "Paste picture", and
  /// where in the text the caret was. Null keeps the keyboard from offering
  /// pictures, and the menu from pasting them.
  final void Function(Uint8List bytes, String mimeType, int offset)?
  onImageInserted;

  /// A search the note was opened from: its matches are marked, and the
  /// first is scrolled into view, until the text is edited.
  final String? highlightTerm;

  /// How [highlightTerm] is read: as a regular expression, matching case.
  final SearchOptions highlightOptions;

  /// Draw the embeds the content may hold (pictures placed in the text).
  final Iterable<EmbedBuilder>? embedBuilders;

  /// The toolbar's camera button, left of the text styles; null hides it.
  final VoidCallback? onTakePicture;

  /// The toolbar's pictures button, next to the camera; null hides it.
  final VoidCallback? onPickImages;

  const RichTextEditor({
    super.key,
    this.initialContent,
    this.onChanged,
    this.onEditingChanged,
    this.hintText = 'Start typing...',
    this.showToolbar = true,
    this.canEdit = true,
    this.focusNode,
    this.contentPadding = const EdgeInsets.symmetric(vertical: 16),
    this.sortChecklistItems = true,
    this.header,
    this.onImageInserted,
    this.highlightTerm,
    this.highlightOptions = const SearchOptions(),
    this.embedBuilders,
    this.onTakePicture,
    this.onPickImages,
  });

  @override
  State<RichTextEditor> createState() => RichTextEditorState();
}

class RichTextEditorState extends State<RichTextEditor>
    with ChecklistReorderMixin, ChecklistDragReorderMixin {
  late QuillController _controller;
  late FocusNode _focusNode;
  late ScrollController _scrollController;
  StreamSubscription<DocChange>? _onChangedSub;
  final GlobalKey<EditorState> _editorKey = GlobalKey<EditorState>();
  final GlobalKey _dragStackKey = GlobalKey();
  bool _isInternalFocusNode = false;
  bool _isEditing = false;
  bool _consumeEditorTapUp = false;

  // ChecklistReorderMixin / ChecklistDragReorderMixin requirements
  @override
  QuillController get controller => _controller;

  @override
  bool get sortChecklistItems => widget.sortChecklistItems;

  @override
  RenderEditor? get renderEditor => _editorKey.currentState?.renderEditor;

  SearchPattern? _highlight;
  StreamSubscription<DocChange>? _highlightSub;

  @override
  ScrollController get dragScrollController => _scrollController;

  @override
  RenderBox? get dragOverlayBox =>
      _dragStackKey.currentContext?.findRenderObject() as RenderBox?;

  @override
  void initState() {
    super.initState();
    _controller = _createController(widget.initialContent);
    _controller.readOnly = !widget.canEdit;
    _scrollController = ScrollController();
    _highlight = SearchPattern(
      widget.highlightTerm ?? '',
      options: widget.highlightOptions,
    );
    if (_highlight!.isEmpty) _highlight = null;
    if (_highlight != null) {
      _highlightSub = _controller.changes.listen((change) {
        if (change.source != ChangeSource.local) return;
        _highlightSub?.cancel();
        if (mounted) setState(() => _highlight = null);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _showFirstMatch());
    }
    _onChangedSub = _controller.changes.listen((_) => widget.onChanged?.call());
    attachChecklistSorting();

    if (widget.focusNode != null) {
      _focusNode = widget.focusNode!;
    } else {
      _focusNode = FocusNode();
      _isInternalFocusNode = true;
    }
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(covariant RichTextEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.canEdit != widget.canEdit) {
      _controller.readOnly = !widget.canEdit;
    }
    if (widget.initialContent != oldWidget.initialContent) {
      _syncExternalContent();
    }
  }

  /// Applies externally reloaded content (restore, unarchive, sync) to the
  /// live controller. No-op when the document already matches. Does not fire
  /// [RichTextEditor.onChanged] and touches neither focus nor the keyboard.
  void _syncExternalContent() {
    final incoming = _parseDocument(widget.initialContent);
    if (incoming.toDelta() == _controller.document.toDelta()) return;

    final previousOffset = _controller.selection.extentOffset;
    cancelChecklistDrag();
    // controller.changes is a stream on the document itself; both
    // subscriptions die with the old one.
    detachChecklistSorting();
    _onChangedSub?.cancel();
    _controller
      ..ignoreFocusOnTextChange = true
      ..skipRequestKeyboard = true
      ..document = incoming;
    _controller.updateSelection(
      TextSelection.collapsed(
        offset: previousOffset.clamp(0, _controller.document.length - 1),
      ),
      ChangeSource.silent,
    );
    _onChangedSub = _controller.changes.listen((_) => widget.onChanged?.call());
    attachChecklistSorting();
    // The armed focus guard suppresses the editor's own repaint.
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller
        ..ignoreFocusOnTextChange = false
        ..skipRequestKeyboard = false;
    });
  }

  @override
  void dispose() {
    disposeChecklistDrag();
    detachChecklistSorting();
    _onChangedSub?.cancel();
    _focusNode.removeListener(_onFocusChanged);
    _controller.dispose();
    _highlightSub?.cancel();
    _scrollController.dispose();
    if (_isInternalFocusNode) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _onFocusChanged() {
    final wasEditing = _isEditing;
    final hasFocus = _focusNode.hasFocus;

    if (!widget.canEdit && hasFocus) {
      SystemChannels.textInput.invokeMethod('TextInput.hide');
      setState(() => _isEditing = false);
    } else {
      setState(() => _isEditing = hasFocus);
    }

    if (wasEditing != _isEditing && widget.canEdit) {
      widget.onEditingChanged?.call(_isEditing);
    }
  }

  QuillController _createController(String? content) {
    // ignore: experimental_member_use
    final config = QuillControllerConfig(
      // ignore: experimental_member_use
      clipboardConfig: QuillClipboardConfig(
        // ignore: experimental_member_use
        onClipboardPaste: _onClipboardPaste,
      ),
    );

    return QuillController(
      document: _parseDocument(content),
      selection: const TextSelection.collapsed(offset: 0),
      config: config,
    );
  }

  Document _parseDocument(String? content) {
    if (content != null && content.isNotEmpty) {
      try {
        final json = jsonDecode(content);
        if (json is Map && json['ops'] is List) {
          return Document.fromJson(json['ops'] as List);
        }
      } catch (_) {
        // Invalid JSON -> empty document
      }
    }
    return Document();
  }

  void _onContentInserted(KeyboardInsertedContent content) {
    final bytes = content.data;
    if (bytes == null || bytes.isEmpty) return;
    widget.onImageInserted?.call(bytes, content.mimeType, caretOffset);
  }

  /// The text selection menu, with "Paste picture" when the clipboard holds
  /// one.
  Widget _contextMenu(BuildContext context, QuillRawEditorState state) {
    final onImage = widget.onImageInserted;
    if (onImage == null || !widget.canEdit) {
      return QuillRawEditorConfig.defaultContextMenuBuilder(context, state);
    }
    return _PastePictureMenu(
      state: state,
      onPaste: (bytes) {
        final at = caretOffset;
        state.hideToolbar();
        onImage(bytes, imageMimeType(bytes), at);
      },
    );
  }

  Future<bool> _onClipboardPaste() async {
    final clip = await Clipboard.getData(Clipboard.kTextPlain);
    final raw = clip?.text?.trim() ?? '';
    if (!isLikelyUrl(raw)) return false;

    final sel = _controller.selection;
    if (!sel.isValid) return false;

    if (sel.isCollapsed) {
      _controller.replaceText(
        sel.start,
        0,
        raw,
        TextSelection.collapsed(offset: sel.start + raw.length),
      );
      _controller.formatText(sel.start, raw.length, LinkAttribute(raw));
    } else {
      _controller.formatText(
        sel.start,
        sel.end - sel.start,
        LinkAttribute(raw),
      );
      _controller.updateSelection(
        TextSelection.collapsed(offset: sel.end),
        ChangeSource.local,
      );
    }
    return true;
  }

  void _openLinkDialog() {
    final selection = _controller.selection;
    final existing = linkAtSelection(_controller);

    final docText = _controller.document.toPlainText();
    final selectedText = (existing == null && !selection.isCollapsed)
        ? docText.substring(selection.start, selection.end)
        : '';
    final selectionIsUrl = existing == null && isLikelyUrl(selectedText);

    LinkEditSheet.show(
      context,
      initialText: existing?.text ?? (selectionIsUrl ? '' : selectedText),
      initialUrl: existing?.url ?? (selectionIsUrl ? selectedText : ''),
      onRemove: existing == null
          ? null
          : () => _removeLinkAt(existing.start, existing.length),
      onSubmit: (text, url) {
        if (existing != null) {
          _replaceLink(existing.start, existing.length, text, url);
        } else if (selection.isCollapsed) {
          final insertAt = selection.start;
          _controller.replaceText(
            insertAt,
            0,
            text,
            TextSelection.collapsed(offset: insertAt + text.length),
          );
          _controller.formatText(insertAt, text.length, LinkAttribute(url));
        } else if (text == selectedText) {
          _controller.formatSelection(LinkAttribute(url));
        } else {
          _replaceLink(
            selection.start,
            selection.end - selection.start,
            text,
            url,
          );
        }
      },
    );
  }

  void _replaceLink(int start, int length, String newText, String newUrl) {
    _controller.replaceText(start, length, '', null);
    _controller.replaceText(
      start,
      0,
      newText,
      TextSelection.collapsed(offset: start + newText.length),
    );
    _controller.formatText(start, newText.length, LinkAttribute(newUrl));
  }

  void _removeLinkAt(int start, int length) {
    _controller.formatText(
      start,
      length,
      Attribute.clone(Attribute.link, null),
    );
  }

  void _handleLaunchUrl(String url) {
    launchExternal(context, url);
  }

  Future<LinkMenuAction> _onLinkLongPress(
    BuildContext ctx,
    String link,
    Node node,
  ) async {
    final range = getLinkRange(node);
    final start = range.start;
    final length = range.end - range.start;
    final text = _controller.document.toPlainText().substring(start, range.end);
    final action = await LinkActionsSheet.show(ctx, text: text, url: link);
    if (action == null || !mounted) return LinkMenuAction.none;
    switch (action) {
      case LinkAction.open:
        _handleLaunchUrl(link);
      case LinkAction.copy:
        await _copyLink(link);
      case LinkAction.edit:
        _editLinkRange(start, length, text, link);
      case LinkAction.remove:
        _removeLinkAt(start, length);
    }
    return LinkMenuAction.none;
  }

  void _editLinkRange(int start, int length, String text, String url) {
    LinkEditSheet.show(
      context,
      initialText: text,
      initialUrl: url,
      onRemove: () => _removeLinkAt(start, length),
      onSubmit: (newText, newUrl) {
        _replaceLink(start, length, newText, newUrl);
      },
    );
  }

  Future<void> _copyLink(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    AppSnackbar.showSuccess(context, message: 'Link copied');
  }

  /// Keeps explicit text colours on highlights, then marks search matches.
  InlineSpan _spanBuilder(
    BuildContext context,
    Node node,
    int nodeOffset,
    String text,
    TextStyle? style,
    GestureRecognizer? recognizer,
  ) {
    final styled = withExplicitTextColor(node, style);
    return _highlight == null
        ? defaultSpanBuilder(
            context,
            node,
            nodeOffset,
            text,
            styled,
            recognizer,
          )
        : _searchSpanBuilder(
            context,
            node,
            nodeOffset,
            text,
            styled,
            recognizer,
          );
  }

  /// Splits [text] so each match of the search term gets a marker colour.
  /// Matches inside a `highlight` keep the marker, so they still stand out.
  InlineSpan _searchSpanBuilder(
    BuildContext context,
    Node node,
    int nodeOffset,
    String text,
    TextStyle? style,
    GestureRecognizer? recognizer,
  ) {
    final hits = _highlight?.allMatches(text).toList() ?? const <Match>[];
    if (hits.isEmpty) {
      return defaultSpanBuilder(
        context,
        node,
        nodeOffset,
        text,
        style,
        recognizer,
      );
    }
    final tint = Theme.of(context).colorScheme.primary.withValues(alpha: 0.3);
    final fill = style?.backgroundColor;
    final mark = (style ?? const TextStyle()).copyWith(
      backgroundColor: fill == null ? tint : Color.alphaBlend(tint, fill),
    );
    final spans = <TextSpan>[];
    var at = 0;
    for (final hit in hits) {
      if (hit.start > at) {
        spans.add(
          TextSpan(
            text: text.substring(at, hit.start),
            style: style,
            recognizer: recognizer,
          ),
        );
      }
      spans.add(
        TextSpan(
          text: text.substring(hit.start, hit.end),
          style: mark,
          recognizer: recognizer,
        ),
      );
      at = hit.end;
    }
    if (at < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(at),
          style: style,
          recognizer: recognizer,
        ),
      );
    }
    return TextSpan(children: spans, style: style);
  }

  void _showFirstMatch() {
    final term = _highlight;
    final editor = renderEditor;
    if (!mounted || term == null || editor == null) return;
    final first = term
        .allMatches(_controller.document.toPlainText())
        .firstOrNull;
    if (first == null) return;
    final at = first.start;
    final rect = editor.getLocalRectForCaret(TextPosition(offset: at));
    editor.showOnScreen(
      rect: rect.inflate(80),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  // Public API
  String getContent() {
    final ops = _controller.document.toDelta().toJson();
    return jsonEncode({'ops': ops});
  }

  bool matchesContent(String? content) =>
      _parseDocument(content).toDelta() == _controller.document.toDelta();

  String getPlainText() => _controller.document.toPlainText().trim();

  bool get isEmpty => _controller.document.toPlainText().trim().isEmpty;

  bool get isEditing => _isEditing;

  /// Puts the caret at the start of the text, as when leaving the title.
  void focusStart() {
    if (!widget.canEdit) return;
    _controller.updateSelection(
      const TextSelection.collapsed(offset: 0),
      ChangeSource.local,
    );
    _focusNode.requestFocus();
  }

  /// Where the caret is in the text, focused or not.
  TextSelection get selection => _controller.selection;

  /// Puts the caret back at [selection], as far as the text still reaches.
  void focusAt(TextSelection selection) {
    if (!widget.canEdit) return;
    final end = _controller.document.length - 1;
    _controller.updateSelection(
      TextSelection(
        baseOffset: selection.baseOffset.clamp(0, end),
        extentOffset: selection.extentOffset.clamp(0, end),
      ),
      ChangeSource.local,
    );
    _focusNode.requestFocus();
  }

  /// Puts the caret at the end of the text, ready to type on.
  void focusEnd() {
    if (!widget.canEdit) return;
    _controller.updateSelection(
      TextSelection.collapsed(offset: _controller.document.length - 1),
      ChangeSource.local,
    );
    _focusNode.requestFocus();
  }

  /// Adds [text] as new lines at the end of the note ("Grab image text").
  void appendText(String text) {
    if (_controller.readOnly || text.trim().isEmpty) return;
    final end = _controller.document.length - 1;
    final isEmpty = _controller.document.toPlainText().trim().isEmpty;
    final insert = isEmpty ? text : '\n$text';
    _controller.replaceText(
      end,
      0,
      insert,
      TextSelection.collapsed(offset: end + insert.length),
    );
  }

  /// Where the caret is, for something to go in there later (a picture
  /// being taken); the end of the text when there is no caret.
  int get caretOffset {
    final selection = _controller.selection;
    final end = _controller.document.length - 1;
    return selection.isValid ? selection.start.clamp(0, end) : end;
  }

  /// Puts [embeds] at [offset] (the caret when null), each on a line of its
  /// own: the line there is split, keeping its style on the part before.
  /// One undo step; the caret goes after them.
  void insertBlockEmbeds(List<BlockEmbed> embeds, {int? offset}) {
    if (_controller.readOnly || embeds.isEmpty) return;
    final end = _controller.document.length - 1;
    final at = (offset ?? caretOffset).clamp(0, end);
    final line = _controller.document.queryChild(at);
    final lineStyle = line.node is Line
        ? (line.node! as Line).style.toJson()
        : null;
    final splits = line.offset > 0;
    final change = Delta()..retain(at);
    if (splits) change.insert('\n', lineStyle);
    for (final embed in embeds) {
      change
        ..insert(embed.toJson())
        ..insert('\n');
    }
    final inserted = (splits ? 1 : 0) + embeds.length * 2;
    final after = TextSelection.collapsed(offset: at + inserted);
    _controller
      ..compose(change, after, ChangeSource.local)
      // compose keeps the caret where it was in the text.
      ..updateSelection(after, ChangeSource.local);
  }

  /// The data of each embed of [type] in the text, in order.
  List<Object?> embedsOf(String type) => [
    for (final op in _controller.document.toDelta().toList())
      if (op.data is Map && (op.data as Map).containsKey(type))
        (op.data as Map)[type],
  ];

  /// Ticked checklist items in the note.
  int get checkedItemCount =>
      parseDocumentLines(_controller.document).where((l) => l.isChecked).length;

  /// Unticks every ticked item, as one undo step.
  void uncheckAll() => _applyBulk(buildUncheckAllDelta);

  /// Whether "Show checkboxes" would turn any line into a checklist item.
  bool get canShowCheckboxes =>
      hasLinesWithoutCheckboxes(parseDocumentLines(_controller.document));

  /// Whether every written line is a checklist item.
  bool get isAllChecklist =>
      allLinesAreChecklist(parseDocumentLines(_controller.document));

  /// Makes every line an unchecked checklist item, as one undo step.
  void showCheckboxes() => _applyBulk(buildShowCheckboxesDelta);

  /// Turns every checklist item back into a plain line, as one undo step.
  void hideCheckboxes() => _applyBulk(buildHideCheckboxesDelta);

  /// Deletes every ticked item, as one undo step.
  void removeChecked() => _applyBulk(buildRemoveCheckedDelta);

  void _applyBulk(Delta? Function(List<ParsedLine> lines) plan) {
    if (_controller.readOnly) return;
    final change = plan(parseDocumentLines(_controller.document));
    if (change == null) return;
    final after = change.transformPosition(_controller.selection.extentOffset);
    _controller.compose(
      change,
      TextSelection.collapsed(
        offset: after.clamp(0, _controller.document.length - 1),
      ),
      ChangeSource.local,
    );
  }

  Widget? _buildLeading(Node node, LeadingConfig config) {
    final isCheck =
        config.attribute == Attribute.checked ||
        config.attribute == Attribute.unchecked;
    if (!isCheck) return null;
    final enabled = config.enabled ?? true;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled
          ? () => _handleCheckboxTap(node.documentOffset, !config.value)
          : null,
      onLongPressStart: enabled
          ? (details) => startChecklistDrag(node.documentOffset, details)
          : null,
      onLongPressMoveUpdate: enabled ? updateChecklistDrag : null,
      onLongPressEnd: enabled ? (_) => endChecklistDrag() : null,
      onLongPressCancel: enabled ? cancelChecklistDrag : null,
      child: AbsorbPointer(
        child: QuillCheckboxPoint(
          size: config.lineSize!,
          value: config.value,
          enabled: enabled,
          uiBuilder: config.uiBuilder,
          onChanged: (_) {},
        ),
      ),
    );
  }

  /// Toggles the checkbox at [offset] without touching selection or focus.
  void _handleCheckboxTap(int offset, bool checked) {
    // Quill's transparent tap recognizer delivers this tap to the editor a
    // second time; [_onEditorTapUp] swallows that duplicate.
    _consumeEditorTapUp = true;
    _controller
      ..ignoreFocusOnTextChange = true
      ..skipRequestKeyboard = true
      ..formatText(
        offset,
        0,
        checked ? Attribute.checked : Attribute.unchecked,
      );
    // While ignoreFocusOnTextChange is armed the editor skips its own repaint.
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _consumeEditorTapUp = false;
      _controller
        ..ignoreFocusOnTextChange = false
        ..skipRequestKeyboard = false;
    });
  }

  /// Swallows the editor-level duplicate of a checkbox tap, which otherwise
  /// moves the cursor to the tapped word and requests the keyboard.
  bool _onEditorTapUp(
    TapUpDetails details,
    TextPosition Function(Offset offset) getPosition,
  ) {
    if (_consumeEditorTapUp) {
      _consumeEditorTapUp = false;
      return true;
    }
    return false;
  }

  /// Tap on empty space around the content: cursor to the end, keyboard up.
  /// The selection update re-requests the keyboard even when focus is kept.
  void _handleBackgroundTap() {
    _focusNode.requestFocus();
    _controller.updateSelection(
      TextSelection.collapsed(offset: _controller.document.length - 1),
      ChangeSource.local,
    );
  }

  Widget _buildScrollableEditor(BuildContext context) {
    return Stack(
      key: _dragStackKey,
      fit: StackFit.expand,
      children: [
        GestureDetector(
          onTap: widget.canEdit ? _handleBackgroundTap : null,
          behavior: HitTestBehavior.opaque,
          child: SingleChildScrollView(
            controller: _scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ?widget.header,
                QuillEditor.basic(
                  controller: _controller,
                  focusNode: _focusNode,
                  scrollController: _scrollController,
                  config: QuillEditorConfig(
                    contentInsertionConfiguration:
                        widget.onImageInserted == null || !widget.canEdit
                        ? null
                        : ContentInsertionConfiguration(
                            allowedMimeTypes: insertableImageTypes,
                            onContentInserted: _onContentInserted,
                          ),
                    contextMenuBuilder: _contextMenu,
                    placeholder: widget.hintText,
                    padding: widget.contentPadding,
                    autoFocus: false,
                    expands: false,
                    scrollable: false,
                    showCursor: _isEditing && widget.canEdit,
                    enableInteractiveSelection: true,
                    customStyles: getEditorStyles(context),
                    textSpanBuilder: _spanBuilder,
                    customStyleBuilder: (attribute) =>
                        getEditorCustomStyle(attribute, context),
                    embedBuilders: widget.embedBuilders,
                    unknownEmbedBuilder: const _UnknownEmbedBuilder(),
                    // ignore: experimental_member_use
                    customLeadingBlockBuilder: _buildLeading,
                    editorKey: _editorKey,
                    onTapUp: _onEditorTapUp,
                    onLaunchUrl: _handleLaunchUrl,
                    linkActionPickerDelegate: _onLinkLongPress,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isDraggingChecklistItem)
          Positioned.fill(
            child: IgnorePointer(
              child: ValueListenableBuilder<int>(
                valueListenable: dragRepaint,
                builder: (context, _, _) => _buildDragOverlay(context),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDragOverlay(BuildContext context) {
    final theme = Theme.of(context);
    final indicatorTop = dragIndicatorTop;
    final feedback = dragFeedbackPosition;
    final sourceRect = dragSourceRect;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxChipLeft = (constraints.maxWidth - 272).clamp(
          12.0,
          double.infinity,
        );
        return Stack(
          children: [
            if (sourceRect != null)
              Positioned.fromRect(
                key: const Key('checklist-drag-dim'),
                rect: sourceRect,
                child: ColoredBox(
                  color: theme.scaffoldBackgroundColor.withValues(alpha: 0.6),
                ),
              ),
            if (indicatorTop != null)
              AnimatedPositioned(
                key: const Key('checklist-drag-indicator'),
                duration: const Duration(milliseconds: 80),
                curve: Curves.easeOut,
                left: dragIndicatorLeft,
                right: 20,
                top: indicatorTop - 4,
                height: 8,
                child: const _DragIndicator(),
              ),
            if (feedback != null)
              Positioned(
                key: const Key('checklist-drag-ghost'),
                left: (feedback.dx + 16).clamp(12.0, maxChipLeft),
                top: (feedback.dy - 52).clamp(4.0, double.infinity),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 260),
                  child: _ChecklistDragChip(
                    text: dragFeedbackText,
                    checked: dragFeedbackChecked,
                    childCount: dragFeedbackChildCount,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: _buildScrollableEditor(context)),
        // Only the bubble and toolbar rebuild on controller changes.
        if (widget.canEdit)
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => _buildEditingChrome(context),
          ),
      ],
    );
  }

  Widget _buildEditingChrome(BuildContext context) {
    final formatting = EditorFormattingState.fromController(_controller);
    final linkUrl = formatting.linkUrl;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_isEditing && linkUrl != null)
          _LinkActionBubble(
            url: linkUrl,
            onOpen: () => _handleLaunchUrl(linkUrl),
            onCopy: () => _copyLink(linkUrl),
            onEdit: _openLinkDialog,
            onRemove: () =>
                _removeLinkAt(formatting.linkStart, formatting.linkLength),
          ),
        if (widget.showToolbar)
          AnimatedSize(
            duration: AppDurations.fast,
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: _isEditing
                ? EditorToolbar(
                    controller: _controller,
                    state: formatting,
                    onLinkPressed: _openLinkDialog,
                    onCameraPressed: widget.onTakePicture,
                    onImagesPressed: widget.onPickImages,
                  )
                : const SizedBox(width: double.infinity),
          ),
      ],
    );
  }
}

/// An embed this app can't draw (from a newer version) stays in the text,
/// shown as a box, so editing the note doesn't lose it.
class _UnknownEmbedBuilder extends EmbedBuilder {
  const _UnknownEmbedBuilder();

  @override
  String get key => '';

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final theme = Theme.of(context);
    return Container(
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        LucideIcons.box,
        size: AppIconSizes.sm,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// Accent line with a dot cap marking the drop gap.
class _DragIndicator extends StatelessWidget {
  const _DragIndicator();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;

    return SizedBox(
      height: 8,
      child: Stack(
        children: [
          Positioned(
            left: 3,
            right: 0,
            top: 3,
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0.5,
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact floating chip showing the item being dragged.
class _ChecklistDragChip extends StatelessWidget {
  final String text;
  final bool checked;
  final int childCount;

  const _ChecklistDragChip({
    required this.text,
    required this.checked,
    required this.childCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dims = context.dims;
    final textColor = checked
        ? theme.colorScheme.onSurface.withValues(alpha: 0.5)
        : theme.colorScheme.onSurface;

    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(10),
      color: theme.colorScheme.surfaceContainerLow,
      shadowColor: Colors.black.withValues(alpha: 0.25),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: dims.sm, vertical: dims.xs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              checked ? LucideIcons.squareCheck : LucideIcons.square,
              size: AppIconSizes.sm,
              color: checked
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            SizedBox(width: dims.xs),
            Flexible(
              child: Text(
                text.isEmpty ? ' ' : text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 15,
                  color: textColor,
                  decoration: checked ? TextDecoration.lineThrough : null,
                  decorationColor: textColor,
                ),
              ),
            ),
            if (childCount > 0) ...[
              SizedBox(width: dims.xs),
              Text(
                '+$childCount',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LinkActionBubble extends StatelessWidget {
  final String url;
  final VoidCallback onOpen;
  final VoidCallback onCopy;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  const _LinkActionBubble({
    required this.url,
    required this.onOpen,
    required this.onCopy,
    required this.onEdit,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dims = context.dims;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: dims.sm, vertical: dims.xs),
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6)
            : theme.colorScheme.surfaceContainerLow,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.15),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            LucideIcons.link,
            size: AppIconSizes.sm,
            color: theme.colorScheme.tertiary,
          ),
          SizedBox(width: dims.xs),
          Expanded(
            child: Text(
              url,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 13,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
              ),
            ),
          ),
          _BubbleAction(
            icon: LucideIcons.externalLink,
            tooltip: 'Open',
            onTap: onOpen,
          ),
          _BubbleAction(icon: LucideIcons.copy, tooltip: 'Copy', onTap: onCopy),
          _BubbleAction(
            icon: LucideIcons.pencil,
            tooltip: 'Edit',
            onTap: onEdit,
          ),
          _BubbleAction(
            icon: LucideIcons.unlink,
            tooltip: 'Remove',
            onTap: onRemove,
            color: theme.colorScheme.error,
          ),
        ],
      ),
    );
  }
}

class _BubbleAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;

  const _BubbleAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor =
        color ?? theme.colorScheme.onSurface.withValues(alpha: 0.7);

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          child: Icon(icon, size: AppIconSizes.sm, color: iconColor),
        ),
      ),
    );
  }
}

/// The selection menu, plus "Paste picture" once the clipboard turns out to
/// hold a picture (asking takes a moment, so it joins the menu then).
class _PastePictureMenu extends StatefulWidget {
  const _PastePictureMenu({required this.state, required this.onPaste});

  final QuillRawEditorState state;
  final ValueChanged<Uint8List> onPaste;

  @override
  State<_PastePictureMenu> createState() => _PastePictureMenuState();
}

class _PastePictureMenuState extends State<_PastePictureMenu> {
  Uint8List? _picture;

  @override
  void initState() {
    super.initState();
    _readClipboard();
  }

  Future<void> _readClipboard() async {
    try {
      // ignore: experimental_member_use
      final bytes = await ClipboardServiceProvider.instance.getImageFile();
      if (mounted && bytes != null && bytes.isNotEmpty) {
        setState(() => _picture = bytes);
      }
    } catch (_) {
      // No picture, or no way to read one here.
    }
  }

  @override
  Widget build(BuildContext context) {
    final picture = _picture;
    return TextFieldTapRegion(
      child: AdaptiveTextSelectionToolbar.buttonItems(
        anchors: widget.state.contextMenuAnchors,
        buttonItems: [
          ...widget.state.contextMenuButtonItems,
          if (picture != null)
            ContextMenuButtonItem(
              label: 'Paste picture',
              onPressed: () => widget.onPaste(picture),
            ),
        ],
      ),
    );
  }
}

/// The picture type [bytes] start like; PNG when unsure.
String imageMimeType(Uint8List bytes) {
  bool starts(List<int> magic) =>
      bytes.length >= magic.length &&
      Iterable.generate(magic.length).every((i) => bytes[i] == magic[i]);
  if (starts([0xFF, 0xD8, 0xFF])) return 'image/jpeg';
  if (starts([0x47, 0x49, 0x46, 0x38])) return 'image/gif';
  if (starts([0x52, 0x49, 0x46, 0x46]) &&
      bytes.length >= 12 &&
      String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
    return 'image/webp';
  }
  return 'image/png';
}
