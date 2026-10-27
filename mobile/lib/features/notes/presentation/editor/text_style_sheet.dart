import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/motion/haptics.dart';
import '../../../../core/motion/springs.dart';
import '../../../../core/theme/context_extensions.dart';
import '../../../../core/theme/tokens/anchor_tokens.dart';
import '../../../../core/widgets/anchor_sheet.dart';
import '../../../../core/widgets/grouped_list.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../core/widgets/segmented_control.dart';
import '../../../../core/widgets/selection_ring.dart';
import '../../../../l10n/l10n.dart';
import 'color_picker_sheet.dart';
import 'text_formats.dart';

/// What the words picked in the editor look like, as the text sheet changes
/// them: each change applies at once.
class TextLook {
  const TextLook({this.highlight, this.color, this.font});

  /// A highlight's name or a custom `#rrggbb`.
  final String? highlight;

  /// `#rrggbb`.
  final String? color;

  /// [TextFont.value].
  final String? font;
}

/// Aa › Color and font: the words' highlight (also any color), text color
/// and font, the same choices as on the web.
Future<void> showTextStyleSheet(
  BuildContext context, {
  required TextLook current,
  required Color Function(String name) highlightFill,
  required ValueChanged<String?> onHighlight,
  required ValueChanged<String?> onColor,
  required ValueChanged<String?> onFont,
}) => showAnchorSheet<void>(
  context,
  semanticLabel: context.l10n.toolTextStyle,
  builder: (_) => _TextStyleSheet(
    current: current,
    highlightFill: highlightFill,
    onHighlight: onHighlight,
    onColor: onColor,
    onFont: onFont,
  ),
);

class _TextStyleSheet extends StatefulWidget {
  const _TextStyleSheet({
    required this.current,
    required this.highlightFill,
    required this.onHighlight,
    required this.onColor,
    required this.onFont,
  });

  final TextLook current;
  final Color Function(String name) highlightFill;
  final ValueChanged<String?> onHighlight;
  final ValueChanged<String?> onColor;
  final ValueChanged<String?> onFont;

  @override
  State<_TextStyleSheet> createState() => _TextStyleSheetState();
}

class _TextStyleSheetState extends State<_TextStyleSheet> {
  late String? _highlight = widget.current.highlight;
  late String? _color = normalizeHex(widget.current.color);
  late String? _font = TextFont.of(widget.current.font)?.value;

  void _pickHighlight(String? value) {
    if (value == _highlight) return;
    Haptics.selection();
    setState(() => _highlight = value);
    widget.onHighlight(value);
  }

  void _pickColor(String? hex) {
    if (hex == _color) return;
    Haptics.selection();
    setState(() => _color = hex);
    widget.onColor(hex);
  }

  void _pickFont(String? font) {
    if (font == _font) return;
    Haptics.selection();
    setState(() => _font = font);
    widget.onFont(font);
  }

  Future<void> _customHighlight() async {
    final current = _highlight;
    final hex = await showColorPickerSheet(
      context,
      title: context.l10n.textStyleCustomHighlight,
      initialHex: colorToHex(
        current == null
            ? widget.highlightFill('yellow')
            : widget.highlightFill(current),
      ),
    );
    if (hex != null && mounted) _pickHighlight(hex);
  }

  Future<void> _customColor() async {
    final hex = await showColorPickerSheet(
      context,
      title: context.l10n.textStyleCustomColor,
      initialHex: _color ?? TextColor.values.first.hex,
    );
    if (hex != null && mounted) _pickColor(hex);
  }

  /// Swatches six to a row, as the background sheet.
  Widget _row(String label, List<Widget> Function(double size) swatches) =>
      Semantics(
        container: true,
        label: label,
        child: LayoutBuilder(
          builder: (context, box) {
            const gap = 12.0;
            final size = (box.maxWidth - gap * 5) / 6;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: swatches(size),
            );
          },
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final names = AnchorTokens.highlightNames;
    final customHighlight = isCustomHighlight(_highlight) ? _highlight : null;
    final isPresetColor = TextColor.values.any((c) => c.hex == _color);
    final customColor = _color != null && !isPresetColor ? _color : null;
    final gap = SizedBox(height: Section.gapOf(context));
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader(title: l10n.toolTextStyle, showDone: true),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Section(
                  label: l10n.toolHighlight,
                  isBoxed: false,
                  child: _row(
                    l10n.toolHighlight,
                    (size) => [
                      _Swatch(
                        size: size,
                        label: l10n.textStyleNone,
                        on: _highlight == null,
                        onTap: () => _pickHighlight(null),
                      ),
                      for (final name in names)
                        _Swatch(
                          size: size,
                          color: widget.highlightFill(name),
                          label: _highlightLabel(name, l10n),
                          on: _highlight == name,
                          onTap: () => _pickHighlight(name),
                        ),
                      _Swatch(
                        size: size,
                        color: parseHexColor(customHighlight),
                        icon: LucideIcons.palette,
                        label: l10n.textStyleCustomHighlight,
                        on: customHighlight != null,
                        onTap: _customHighlight,
                      ),
                    ],
                  ),
                ),
                gap,
                Section(
                  label: l10n.textStyleColor,
                  isBoxed: false,
                  child: _row(
                    l10n.textStyleColor,
                    (size) => [
                      _Swatch(
                        size: size,
                        label: l10n.textStyleDefault,
                        on: _color == null,
                        onTap: () => _pickColor(null),
                      ),
                      for (final color in TextColor.values)
                        _Swatch(
                          size: size,
                          color: color.color,
                          label: color.labelIn(l10n),
                          on: _color == color.hex,
                          onTap: () => _pickColor(color.hex),
                        ),
                      _Swatch(
                        size: size,
                        color: parseHexColor(customColor),
                        icon: LucideIcons.palette,
                        label: l10n.textStyleCustomColor,
                        on: customColor != null,
                        onTap: _customColor,
                      ),
                    ],
                  ),
                ),
                gap,
                Section(
                  label: l10n.textStyleFont,
                  isBoxed: false,
                  child: SegmentedControl<String?>(
                    semanticLabel: l10n.textStyleFont,
                    value: _font,
                    segments: [
                      Segment(value: null, label: l10n.textStyleDefault),
                      for (final font in TextFont.values)
                        Segment(
                          value: font.value,
                          label: font.labelIn(l10n),
                          fontFamily: font.family,
                        ),
                    ],
                    onChanged: _pickFont,
                  ),
                ),
                const SheetBottomSpace(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

String _highlightLabel(String name, AppLocalizations l10n) => switch (name) {
  'green' => l10n.colorGreen,
  'blue' => l10n.colorBlue,
  'pink' => l10n.colorPink,
  'purple' => l10n.colorPurple,
  _ => l10n.colorYellow,
};

/// A round color to pick, with a check when it's the chosen one. Without a
/// [color] it shows [icon] (or a "none" mark) on the sheet.
class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.size,
    required this.label,
    required this.on,
    required this.onTap,
    this.color,
    this.icon,
  });

  final double size;
  final String label;
  final bool on;
  final VoidCallback onTap;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    final radius = BorderRadius.circular(size);
    final fill = color;
    return Pressable(
      style: PressStyle.thumb,
      onTap: onTap,
      semanticLabel: label,
      selected: on,
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: SelectionRing(
                isShown: on,
                borderRadius: radius,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: fill ?? GroupedList.fillOf(context),
                    borderRadius: radius,
                    border: Border.all(color: colors.appBorder),
                  ),
                  child: Center(
                    child: icon != null
                        ? Icon(
                            icon,
                            size: AnchorTokens.sizeIconMedium,
                            color: fill == null ? colors.appMuted : inkOn(fill),
                          )
                        : fill == null
                        ? Icon(
                            LucideIcons.ban,
                            size: AnchorTokens.sizeIconMedium,
                            color: colors.appMuted,
                          )
                        : null,
                  ),
                ),
              ),
            ),
            Positioned(
              right: -2, // off-scale: the chosen badge on a swatch
              bottom: -2, // off-scale: as above
              child: AnimatedScale(
                scale: on ? 1 : 0,
                duration: context.motion(Spring.pop.duration),
                curve: Spring.pop.curve,
                child: Container(
                  width: 20, // off-scale: the chosen badge on a swatch
                  height: 20, // off-scale: as above
                  decoration: BoxDecoration(
                    color: colors.accentStrong,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    LucideIcons.check600,
                    size: 12, // off-scale: as above
                    color: colors.checkMark,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
