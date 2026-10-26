import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/files/image_text.dart';
import '../../../../core/theme/context_extensions.dart';
import '../../../../core/widgets/app_snackbar.dart';

/// A picture with the text found in it marked, to pick some of it, as the
/// text actions on Windows do: hold on a word and drag to select, or select
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
  /// The selected words, as a range in reading order: where the hold started
  /// and where the finger is.
  int? _anchor;
  int? _focus;

  List<ImageWord> get _words => widget.text.words;

  bool get _hasSelection => _anchor != null && _focus != null;

  int get _first => math.min(_anchor!, _focus!);
  int get _last => math.max(_anchor!, _focus!);

  bool _isSelected(int index) =>
      _hasSelection && index >= _first && index <= _last;

  String get _selectedText => joinImageWords(_words.sublist(_first, _last + 1));

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

  int? _wordAt(Offset position, Size box) {
    final fit = _fit(box);
    return imageWordAt(
      _words,
      (position - fit.offset) / fit.scale,
      slop: 12 / fit.scale,
    );
  }

  void _selectAll() => setState(() {
    _anchor = 0;
    _focus = _words.length - 1;
  });

  void _clear() => setState(() => _anchor = _focus = null);

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _selectedText));
    if (mounted) AppSnackbar.showSuccess(context, message: 'Text copied');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dims = context.dims;
    final words = _words.length;
    final chosen = _hasSelection ? _last - _first + 1 : 0;

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
                  onLongPressStart: (details) {
                    final index = _wordAt(details.localPosition, box);
                    if (index == null) return;
                    HapticFeedback.selectionClick();
                    setState(() => _anchor = _focus = index);
                  },
                  onLongPressMoveUpdate: (details) {
                    if (_anchor == null) return;
                    final index = _wordAt(details.localPosition, box);
                    if (index != null && index != _focus) {
                      HapticFeedback.selectionClick();
                      setState(() => _focus = index);
                    }
                  },
                  onTapUp: (details) {
                    final index = _wordAt(details.localPosition, box);
                    if (index == null) {
                      _clear();
                    } else {
                      setState(() => _anchor = _focus = index);
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
                  if (chosen == 0)
                    Padding(
                      padding: EdgeInsets.only(bottom: dims.sm),
                      child: Text(
                        'Hold a word and drag to select text',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                    ),
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
  });

  final List<ImageWord> words;
  final bool Function(int index) isSelected;
  final double scale;
  final Offset offset;
  final Color selectedColor;

  @override
  void paint(Canvas canvas, Size size) {
    final found = Paint()..color = Colors.white.withValues(alpha: 0.14);
    final edge = Paint()
      ..color = Colors.white.withValues(alpha: 0.32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final chosen = Paint()..color = selectedColor.withValues(alpha: 0.45);
    for (final (i, word) in words.indexed) {
      final rect = Rect.fromLTRB(
        offset.dx + word.rect.left * scale,
        offset.dy + word.rect.top * scale,
        offset.dx + word.rect.right * scale,
        offset.dy + word.rect.bottom * scale,
      ).inflate(2);
      final shape = RRect.fromRectAndRadius(rect, const Radius.circular(3));
      if (isSelected(i)) {
        canvas.drawRRect(shape, chosen);
      } else {
        canvas
          ..drawRRect(shape, found)
          ..drawRRect(shape, edge);
      }
    }
  }

  // The selection lives in the view's state, so any rebuild may change it.
  @override
  bool shouldRepaint(_WordsPainter oldDelegate) => true;
}
