import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/files/image_text.dart';
import '../../../../core/motion/haptics.dart';
import '../../../../core/motion/springs.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/context_extensions.dart';
import '../../../../core/theme/system_bars.dart';
import '../../../../core/theme/tokens/anchor_tokens.dart';
import '../../../../core/widgets/app_buttons.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/cap_height_text.dart';
import '../../../../core/widgets/page_bar.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../l10n/l10n.dart';

/// A picture with the text found in it marked, to pick some of it, as the
/// text actions on Windows do: hold on a word and drag to select the words
/// in between, hold beside the text and drag a box over words, tap a word, or
/// select all; then copy it or put it in the note.
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

  /// While a hold that started on a word drags: that word.
  int? _anchor;

  /// While a hold that started beside the text drags: the box drawn, in the
  /// picture's pixels.
  Offset? _boxStart;
  Rect? _box;

  List<ImageWord> get _words => widget.text.words;

  bool _isSelected(int index) => _selected.contains(index);

  String get _selectedText =>
      joinImageWords([for (final i in _selected.toList()..sort()) _words[i]]);

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

  void _select(Iterable<int> indices) {
    final next = indices.toSet();
    if (next.length != _selected.length || !next.containsAll(_selected)) {
      Haptics.selection();
    }
    setState(() => _selected = next);
  }

  void _onHoldStart(Offset position, Size box) {
    final index = _wordAt(position, box);
    if (index != null) {
      _anchor = index;
      _select({index});
    } else {
      // Beside the text: a box, which starts empty.
      Haptics.selection();
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
      _select(imageWordsIn(_words, area));
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
    if (!mounted) return;
    Haptics.success();
    AppSnackbar.show(
      context,
      context.l10n.pictureTextCopied,
      kind: SnackbarKind.success,
    );
  }

  void _insert() {
    Haptics.success();
    widget.onInsert!(_selectedText);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final media = MediaQuery.of(context);
    final chosen = _selected.length;
    const ink = AnchorTokens.colorMediaText;
    final onInsert = widget.onInsert;

    return Material(
      color: Colors.black,
      child: Column(
        children: [
          PageBar(
            isTitleCentered: true,
            color: Colors.black,
            systemBars: systemBarsStyle(dark: true),
            leading: BarButton(
              icon: LucideIcons.x,
              label: l10n.commonClose,
              color: ink,
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Semantics(
              liveRegion: true,
              child: CapHeightText(
                chosen == 0
                    ? l10n.pictureSelectText
                    : l10n.pictureWordsSelected(chosen),
                style: AppTypography.secondary.copyWith(
                  fontWeight: FontWeight.w600,
                  color: ink,
                ),
              ),
            ),
          ),
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
                      Semantics(
                        image: true,
                        label: widget.text.text,
                        child: Image(
                          image: widget.image,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.medium,
                          gaplessPlayback: true,
                          errorBuilder: (_, _, _) => const SizedBox.expand(),
                        ),
                      ),
                      CustomPaint(
                        painter: _WordsPainter(
                          words: _words,
                          isSelected: _isSelected,
                          scale: fit.scale,
                          offset: fit.offset,
                          selectedColor: context.anchor.accentStrong,
                          box: _box,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              AnchorTokens.spaceGutterPhone,
              context.density.space12,
              AnchorTokens.spaceGutterPhone,
              media.padding.bottom + context.density.space12,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: context.density.space12,
              children: [
                if (chosen == 0)
                  Text(
                    l10n.pictureSelectHint,
                    textAlign: TextAlign.center,
                    style: AppTypography.footnote.copyWith(
                      color: AnchorTokens.colorMediaMuted,
                    ),
                  ),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MediaPill(
                      icon: LucideIcons.textSelect,
                      label: l10n.commonSelectAll,
                      onPressed: chosen == _words.length ? null : _selectAll,
                    ),
                    _MediaPill(
                      icon: LucideIcons.copy,
                      label: l10n.commonCopy,
                      onPressed: chosen == 0 ? null : _copy,
                    ),
                    if (onInsert != null)
                      _MediaPill(
                        icon: LucideIcons.textCursorInput,
                        label: l10n.pictureInsertText,
                        isProminent: true,
                        onPressed: chosen == 0 ? null : _insert,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A pill button on the dark picture page: a light wash, or white for the
/// main action.
class _MediaPill extends StatelessWidget {
  const _MediaPill({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isProminent = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool isProminent;

  @override
  Widget build(BuildContext context) {
    final foreground = isProminent
        ? AnchorTokens.colorMediaScrim
        : AnchorTokens.colorMediaText;
    final enabled = onPressed != null;
    return Pressable(
      style: PressStyle.button,
      onTap: onPressed,
      semanticLabel: label,
      child: AnimatedOpacity(
        opacity: enabled ? 1 : DisabledOpacity.button,
        duration: context.motion(AnchorTokens.motionDurationFade),
        child: Container(
          height: AnchorTokens.sizeControlMedium,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isProminent
                ? AnchorTokens.colorMediaText
                : AnchorTokens.colorMediaControl,
            borderRadius: BorderRadius.circular(AnchorTokens.radiusPill),
          ),
          child: ExcludeSemantics(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [
                Icon(
                  icon,
                  size: AnchorTokens.sizeIconMedium,
                  color: foreground,
                ),
                Text(
                  label,
                  style: AppTypography.secondary.copyWith(
                    fontWeight: FontWeight.w600,
                    color: foreground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A light wash over every word found, and the accent over the chosen ones.
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
