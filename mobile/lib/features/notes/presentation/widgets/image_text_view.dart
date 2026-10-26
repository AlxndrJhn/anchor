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
/// text actions on Windows do: hold on a word and drag to select, tap a word,
/// or select all; then copy it or put it in the note.
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

  void _selectAll() {
    Haptics.selection();
    setState(() {
      _anchor = 0;
      _focus = _words.length - 1;
    });
  }

  void _clear() => setState(() => _anchor = _focus = null);

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
    final chosen = _hasSelection ? _last - _first + 1 : 0;
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
                  onLongPressStart: (details) {
                    final index = _wordAt(details.localPosition, box);
                    if (index == null) return;
                    Haptics.selection();
                    setState(() => _anchor = _focus = index);
                  },
                  onLongPressMoveUpdate: (details) {
                    if (_anchor == null) return;
                    final index = _wordAt(details.localPosition, box);
                    if (index != null && index != _focus) {
                      Haptics.selection();
                      setState(() => _focus = index);
                    }
                  },
                  onTapUp: (details) {
                    final index = _wordAt(details.localPosition, box);
                    if (index == null) {
                      _clear();
                    } else {
                      Haptics.selection();
                      setState(() => _anchor = _focus = index);
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
