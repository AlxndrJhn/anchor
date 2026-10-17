import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../../../../core/motion/haptics.dart';
import '../../../../core/theme/tokens/anchor_tokens.dart';
import 'checklist_lines.dart';
import 'document_lines.dart';

class ChecklistDragController extends ChangeNotifier {
  ChecklistDragController({
    required QuillController controller,
    required RenderEditor? Function() editor,
    required RenderBox? Function() overlay,
    required ScrollController Function() scrollController,
    required TickerProvider vsync,
    required this.onDrop,
    Rect? Function()? visibleArea,
    bool Function(int offset)? isFolded,
    double Function()? listEndGap,
  }) : _controller = controller,
       _editor = editor,
       _overlay = overlay,
       _scrollController = scrollController,
       _visibleArea = visibleArea ?? (() => null),
       _isFolded = isFolded ?? ((_) => false),
       _listEndGap = listEndGap ?? (() => 0) {
    _scroller = vsync.createTicker(_scrollTick);
  }

  final QuillController _controller;

  final RenderEditor? Function() _editor;

  final RenderBox? Function() _overlay;

  final ScrollController Function() _scrollController;

  /// In global coordinates.
  final Rect? Function() _visibleArea;

  final bool Function(int offset) _isFolded;

  final double Function() _listEndGap;

  final ValueChanged<Delta> onDrop;

  late final Ticker _scroller;

  static const double _topEdge = 40; // off-scale: autoscroll edge
  static const double _bottomEdge = 56; // off-scale: autoscroll edge

  /// Per frame at 60 a second.
  static const double _speedPerDistance = 0.25;
  static const double _maxSpeed = 14; // off-scale: per frame

  static const double _indentStep = AnchorTokens.sizeListIndent;

  static const double _textInset = AnchorTokens.space32;

  List<ParsedLine>? _lines;
  int? _lineIndex;
  int _blockEnd = 0;
  int _groupStart = 0;
  int _groupEnd = 0;
  List<ChecklistGap> _validGaps = const [];
  int? _hoverGap;
  int? _hoverIndent;
  double _startX = 0;
  Offset? _globalPosition;
  String _text = '';
  bool _isChecked = false;
  Duration? _lastTick;
  bool _isDisposed = false;

  final ValueNotifier<TextRange?> _dragged = ValueNotifier(null);

  /// From the first item's start to the last one's line break.
  ValueListenable<TextRange?> get dragged => _dragged;

  bool get isDragging => _lineIndex != null;

  String get text => _text;

  bool get isChecked => _isChecked;

  int get childCount {
    final index = _lineIndex;
    return index == null ? 0 : _blockEnd - index;
  }

  /// In global coordinates.
  Offset? get finger => isDragging ? _globalPosition : null;

  /// In overlay coordinates.
  double get indicatorLeft {
    final editor = _editor();
    final box = _overlay();
    final lines = _lines;
    final index = _lineIndex;
    if (editor == null || box == null || lines == null || index == null) {
      return 0;
    }
    final left = box.globalToLocal(editor.localToGlobal(Offset.zero)).dx;
    final indent = _hoverIndent ?? lines[index].indent;
    return left + _textInset + _indentStep * indent;
  }

  /// In overlay coordinates; null while the drop would change nothing.
  double? get indicatorY {
    final gap = _hoverGap;
    final lines = _lines;
    final index = _lineIndex;
    final editor = _editor();
    final box = _overlay();
    if (gap == null || lines == null || index == null) return null;
    if (editor == null || box == null) return null;
    if (gap >= index &&
        gap <= _blockEnd + 1 &&
        _hoverIndent == lines[index].indent) {
      return null;
    }
    final y = _gapY(editor, lines, gap);
    return box.globalToLocal(editor.localToGlobal(Offset(0, y))).dy;
  }

  double _gapY(RenderEditor editor, List<ParsedLine> lines, int gap) {
    if (gap <= _groupEnd) return _lineBox(editor, lines[gap]).top;
    return _lineBox(editor, lines[_groupEnd]).bottom - _listEndGap();
  }

  (double, double) _gapSpan(
    RenderEditor editor,
    List<ParsedLine> lines,
    int gap,
  ) {
    final index = _lineIndex!;
    final isOwn = gap >= index && gap <= _blockEnd + 1;
    final above = isOwn ? index - 1 : gap - 1;
    final below = isOwn ? _blockEnd + 1 : gap;
    return (
      above >= _groupStart
          ? _lineCenterY(editor, lines[above])
          : double.negativeInfinity,
      below <= _groupEnd ? _lineCenterY(editor, lines[below]) : double.infinity,
    );
  }

  double _lineCenterY(RenderEditor editor, ParsedLine line) {
    final top = editor.getLocalRectForCaret(
      TextPosition(offset: line.startOffset),
    );
    final bottom = editor.getLocalRectForCaret(
      TextPosition(offset: line.startOffset + line.length - 1),
    );
    return (top.top + bottom.bottom) / 2;
  }

  Rect _lineBox(RenderEditor editor, ParsedLine line) {
    final position = TextPosition(offset: line.startOffset);
    RenderBox box = editor.childAtPosition(position);
    var space = EdgeInsets.zero;
    if (box is RenderEditableContainerBox) {
      final block = box;
      box = block.childAtPosition(
        TextPosition(offset: line.startOffset - block.container.documentOffset),
      );
      final padding = block.getPadding().resolve(TextDirection.ltr);
      space = EdgeInsets.only(
        top: box == block.firstChild ? padding.top : 0,
        bottom: box == block.lastChild ? padding.bottom : 0,
      );
    }
    final topLeft = editor.globalToLocal(box.localToGlobal(Offset.zero));
    return space.inflateRect(topLeft & box.size);
  }

  void start(int documentOffset, LongPressStartDetails details) {
    final editor = _editor();
    if (editor == null || isDragging) return;

    final lines = parseDocumentLines(_controller.document);
    final index = lineIndexAt(lines, documentOffset);
    if (index == -1 || !lines[index].isChecklist) return;

    final (groupStart, groupEnd) = checklistGroupAround(lines, index);
    final blockEnd = checklistBlockEnd(lines, index, groupEnd);
    final gaps = [
      for (final gap in checklistDropGaps(
        lines,
        groupStart,
        groupEnd,
        index,
        blockEnd,
      ))
        if (!_isFoldedGap(lines, gap.gap)) gap,
    ];
    final isNoOp = gaps.every(
      (g) =>
          g.gap >= index && g.gap <= blockEnd + 1 && g.minIndent == g.maxIndent,
    );
    if (isNoOp) return;

    final line = lines[index];
    final last = lines[blockEnd];
    final text = _controller.document.toPlainText().substring(
      line.startOffset,
      line.startOffset + line.length - 1,
    );

    Haptics.medium();
    _lines = lines;
    _lineIndex = index;
    _blockEnd = blockEnd;
    _groupStart = groupStart;
    _groupEnd = groupEnd;
    _validGaps = gaps;
    _hoverGap = null;
    _hoverIndent = null;
    _startX = details.globalPosition.dx;
    _text = text;
    _isChecked = line.isChecked;
    _globalPosition = details.globalPosition;
    _dragged.value = TextRange(
      start: line.startOffset,
      end: last.startOffset + last.length - 1,
    );
    HardwareKeyboard.instance.addHandler(_onKey);
    _updateHover(details.globalPosition);
  }

  bool _isFoldedGap(List<ParsedLine> lines, int gap) =>
      gap > 0 && _isFolded(lines[gap - 1].startOffset);

  void update(LongPressMoveUpdateDetails details) {
    if (!isDragging) return;
    _updateHover(details.globalPosition);
  }

  void end() {
    if (!isDragging) return;
    final index = _lineIndex;
    final blockEnd = _blockEnd;
    final gap = _hoverGap;
    final indent = _hoverIndent;
    final snapshot = _lines;
    _stopAutoScroll();

    if (index == null || gap == null || indent == null || snapshot == null) {
      _reset();
      return;
    }
    final ownBoundary = gap >= index && gap <= blockEnd + 1;
    final indentDelta = indent - snapshot[index].indent;
    if (ownBoundary && indentDelta == 0) {
      _reset();
      return;
    }

    // A sync can swap the document mid-drag: compose only if it still matches.
    final lines = parseDocumentLines(_controller.document);
    var matches = lines.length == snapshot.length && gap <= lines.length;
    for (var i = index; matches && i <= blockEnd; i++) {
      matches = _sameLine(lines[i], snapshot[i]);
    }
    if (matches && gap < lines.length) {
      matches = _sameLine(lines[gap], snapshot[gap]);
    }
    if (!matches) {
      _reset();
      return;
    }

    final move = ownBoundary
        ? buildBlockReindentDelta(lines, index, blockEnd, indentDelta)
        : buildBlockMoveDelta(
            _controller.document,
            lines,
            index,
            blockEnd,
            gap,
            indentDelta: indentDelta,
          );
    _reset();
    onDrop(move);
    Haptics.light();
  }

  void cancel() {
    if (!isDragging) return;
    _stopAutoScroll();
    _reset();
  }

  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.escape) {
      return false;
    }
    cancel();
    return true;
  }

  @override
  void dispose() {
    _isDisposed = true;
    _stopAutoScroll();
    _scroller.dispose();
    HardwareKeyboard.instance.removeHandler(_onKey);
    _dragged.dispose();
    super.dispose();
  }

  void _updateHover(Offset globalPosition) {
    final editor = _editor();
    final lines = _lines;
    if (editor == null || lines == null || !isDragging) return;

    final localY = editor.globalToLocal(globalPosition).dy;
    var entry = _validGaps.first;
    var bestDistance = double.infinity;
    for (final gap in _validGaps) {
      final (top, bottom) = _gapSpan(editor, lines, gap.gap);
      final distance = localY < top
          ? top - localY
          : localY > bottom
          ? localY - bottom
          : 0.0;
      if (distance < bestDistance) {
        bestDistance = distance;
        entry = gap;
      }
    }
    final head = lines[_lineIndex!].indent;
    var indent = head + ((globalPosition.dx - _startX) / _indentStep).round();
    if (indent < entry.minIndent) indent = entry.minIndent;
    if (indent > entry.maxIndent) indent = entry.maxIndent;

    if (entry.gap != _hoverGap || indent != _hoverIndent) {
      if (_hoverGap != null) Haptics.selection();
      _hoverGap = entry.gap;
      _hoverIndent = indent;
    }
    _globalPosition = globalPosition;
    notifyListeners();
    if (_scrollSpeed(globalPosition.dy) != 0 && !_scroller.isActive) {
      _lastTick = null;
      _scroller.start();
    }
  }

  /// Pixels per frame at 60 a second; up is negative.
  double _scrollSpeed(double y) {
    final area = _visibleArea() ?? _viewport();
    if (area == null) return 0;
    final top = area.top + _topEdge;
    final bottom = area.bottom - _bottomEdge;
    final speed = y < top
        ? (y - top) * _speedPerDistance
        : y > bottom
        ? (y - bottom) * _speedPerDistance
        : 0.0;
    return speed.clamp(-_maxSpeed, _maxSpeed);
  }

  Rect? _viewport() {
    final scroll = _scrollController();
    if (!scroll.hasClients) return null;
    final box = scroll.position.context.notificationContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  void _scrollTick(Duration elapsed) {
    final global = _globalPosition;
    final scroll = _scrollController();
    final speed = global == null ? 0.0 : _scrollSpeed(global.dy);
    if (!isDragging || speed == 0 || !scroll.hasClients) {
      _stopAutoScroll();
      return;
    }
    final frames = _lastTick == null
        ? 1.0
        : (elapsed - _lastTick!).inMicroseconds / (1e6 / 60);
    _lastTick = elapsed;
    final position = scroll.position;
    final next = (position.pixels + speed * frames).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (next == position.pixels) return;
    position.jumpTo(next);
    _updateHover(global!);
  }

  void _stopAutoScroll() {
    if (_scroller.isActive) _scroller.stop();
  }

  void _reset() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _lines = null;
    _lineIndex = null;
    _blockEnd = 0;
    _groupStart = 0;
    _groupEnd = 0;
    _validGaps = const [];
    _hoverGap = null;
    _hoverIndent = null;
    _globalPosition = null;
    _text = '';
    if (_isDisposed) return;
    _dragged.value = null;
    notifyListeners();
  }

  bool _sameLine(ParsedLine a, ParsedLine b) =>
      a.startOffset == b.startOffset &&
      a.length == b.length &&
      a.listType == b.listType &&
      a.indent == b.indent;
}
