import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/files/image_text.dart';
import '../../../../core/theme/context_extensions.dart';
import '../../../../core/widgets/app_snackbar.dart';

/// A picture with the text found in it marked, to pick some of it, as the
/// text actions on Windows do: hold on a word and drag to select the words
/// in between, hold beside the text and drag a box over words, or select
/// all; then copy it or put it in the note.
class ImageTextView extends StatefulWidget {
  const ImageTextView({
    super.key,
    required this.image,
    required this.imageSize,
    required this.text,
    this.onInsert,
  });

  final ImageProvider image;

  /// The picture's size in pixels, which the words' places are measured in.
  final Size imageSize;

  final ImageText text;

  /// Puts the chosen text in the note; null when the note can't be edited.
  final ValueChanged<String>? onInsert;

  @override
  State<ImageTextView> createState() => _ImageTextViewState();
}

class _ImageTextViewState extends State<ImageTextView> {
  /// The selected words, by index.
  Set<int> _selected = {};

  /// Whether the selection was boxed in, which can take words from anywhere
  /// on the picture: its text keeps no blank lines between paragraphs.
  bool _boxed = false;

  /// While a hold that started on a word drags: that word.
  int? _anchor;

  /// While a hold that started beside the text drags: the box drawn, in the
  /// picture's pixels.
  Offset? _boxStart;
  Rect? _box;

  List<ImageWord> get _words => widget.text.words;

  bool _isSelected(int index) => _selected.contains(index);

  String get _selectedText => joinImageWords([
    for (final i in _selected.toList()..sort()) _words[i],
  ], paragraphs: !_boxed);

  /// The hint shows until something is picked, and fades while holding.
  bool get _showHint => _selected.isEmpty && _box == null && _anchor == null;

  /// Where the picture sits in [box] (shown whole, centred), and its scale.
  ({double scale, Offset offset}) _fit(Size box) {
    final scale = math.min(
      box.width / widget.imageSize.width,
      box.height / widget.imageSize.height,
    );
    final offset = Offset(
      (box.width - widget.imageSize.width * scale) / 2,
      (box.height - widget.imageSize.height * scale) / 2,
    );
    return (scale: scale, offset: offset);
  }

  /// A point on the screen in the picture's pixels.
  Offset _toImage(Offset position, Size box) {
    final fit = _fit(box);
    return (position - fit.offset) / fit.scale;
  }

  int? _wordAt(Offset position, Size box) =>
      imageWordAt(_words, _toImage(position, box), slop: 12 / _fit(box).scale);

  void _select(Iterable<int> indices, {bool boxed = false}) {
    final next = indices.toSet();
    if (next.length != _selected.length || !next.containsAll(_selected)) {
      HapticFeedback.selectionClick();
    }
    setState(() {
      _selected = next;
      _boxed = boxed;
    });
  }

  void _onHoldStart(Offset position, Size box) {
    final index = _wordAt(position, box);
    if (index != null) {
      _anchor = index;
      _select({index});
    } else {
      // Beside the text: a box, which starts empty.
      HapticFeedback.selectionClick();
      final at = _toImage(position, box);
      setState(() {
        _boxStart = at;
        _box = Rect.fromPoints(at, at);
        _selected = {};
      });
    }
  }

  void _onHoldMove(Offset position, Size box) {
    final anchor = _anchor;
    final start = _boxStart;
    if (anchor != null) {
      final index = _wordAt(position, box);
      if (index == null) return;
      final first = math.min(anchor, index), last = math.max(anchor, index);
      _select([for (var i = first; i <= last; i++) i]);
    } else if (start != null) {
      final area = Rect.fromPoints(start, _toImage(position, box));
      _box = area;
      _select(imageWordsIn(_words, area), boxed: true);
    }
  }

  void _onHoldEnd() => setState(() {
    _anchor = null;
    _boxStart = null;
    _box = null;
  });

  void _selectAll() => _select([for (var i = 0; i < _words.length; i++) i]);

  void _clear() => setState(() => _selected = {});

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _selectedText));
    if (mounted) AppSnackbar.showSuccess(context, message: 'Text copied');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dims = context.dims;
    final words = _words.length;
    final chosen = _selected.length;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(LucideIcons.x),
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          chosen == 0
              ? 'Select text'
              : chosen == 1
              ? '1 word selected'
              : '$chosen words selected',
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final box = constraints.biggest;
                final fit = _fit(box);
                return GestureDetector(
                  key: const ValueKey('image-text-area'),
                  behavior: HitTestBehavior.opaque,
                  onLongPressStart: (details) =>
                      _onHoldStart(details.localPosition, box),
                  onLongPressMoveUpdate: (details) =>
                      _onHoldMove(details.localPosition, box),
                  onLongPressEnd: (_) => _onHoldEnd(),
                  onLongPressCancel: _onHoldEnd,
                  onTapUp: (details) {
                    final index = _wordAt(details.localPosition, box);
                    if (index == null) {
                      _clear();
                    } else {
                      _select({index});
                    }
                  },
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image(image: widget.image, fit: BoxFit.contain),
                      CustomPaint(
                        painter: _WordsPainter(
                          words: _words,
                          isSelected: _isSelected,
                          scale: fit.scale,
                          offset: fit.offset,
                          selectedColor: theme.colorScheme.primary,
                          box: _box,
                        ),
                      ),
                      // Over the picture, so its coming and going doesn't
                      // move the picture under the finger.
                      Positioned(
                        left: dims.md,
                        right: dims.md,
                        bottom: dims.sm,
                        child: IgnorePointer(
                          child: AnimatedOpacity(
                            opacity: _showHint ? 1 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: Center(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: dims.sm,
                                    vertical: dims.xs,
                                  ),
                                  child: Text(
                                    'Hold a word and drag to select text, or '
                                    'hold beside it and drag a box',
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(dims.md, dims.sm, dims.md, dims.sm),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: dims.sm,
                    runSpacing: dims.sm,
                    children: [
                      _ActionButton(
                        icon: LucideIcons.textSelect,
                        label: 'Select all',
                        onPressed: chosen == words ? null : _selectAll,
                      ),
                      _ActionButton(
                        icon: LucideIcons.copy,
                        label: 'Copy',
                        onPressed: chosen == 0 ? null : _copy,
                      ),
                      if (widget.onInsert != null)
                        _ActionButton(
                          icon: LucideIcons.textCursorInput,
                          label: 'Insert in note',
                          filled: true,
                          onPressed: chosen == 0
                              ? null
                              : () => widget.onInsert!(_selectedText),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    if (filled) {
      return FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
      );
    }
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white38,
        side: const BorderSide(color: Colors.white38),
      ),
    );
  }
}

/// A light wash over every word found, and a stronger one over the chosen.
class _WordsPainter extends CustomPainter {
  _WordsPainter({
    required this.words,
    required this.isSelected,
    required this.scale,
    required this.offset,
    required this.selectedColor,
    this.box,
  });

  final List<ImageWord> words;
  final bool Function(int index) isSelected;
  final double scale;
  final Offset offset;
  final Color selectedColor;

  /// The box being drawn, in the picture's pixels.
  final Rect? box;

  Rect _onScreen(Rect rect) => Rect.fromLTRB(
    offset.dx + rect.left * scale,
    offset.dy + rect.top * scale,
    offset.dx + rect.right * scale,
    offset.dy + rect.bottom * scale,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final found = Paint()..color = Colors.white.withValues(alpha: 0.14);
    final edge = Paint()
      ..color = Colors.white.withValues(alpha: 0.32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final chosen = Paint()..color = selectedColor.withValues(alpha: 0.45);
    for (final (i, word) in words.indexed) {
      final rect = _onScreen(word.rect).inflate(2);
      final shape = RRect.fromRectAndRadius(rect, const Radius.circular(3));
      if (isSelected(i)) {
        canvas.drawRRect(shape, chosen);
      } else {
        canvas
          ..drawRRect(shape, found)
          ..drawRRect(shape, edge);
      }
    }
    final area = box;
    if (area != null) {
      final rect = _onScreen(area);
      canvas
        ..drawRect(rect, Paint()..color = selectedColor.withValues(alpha: 0.12))
        ..drawRect(
          rect,
          Paint()
            ..color = selectedColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
    }
  }

  // The selection lives in the view's state, so any rebuild may change it.
  @override
  bool shouldRepaint(_WordsPainter oldDelegate) => true;
}
