import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/motion/haptics.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/context_extensions.dart';
import '../../../../core/theme/tokens/anchor_tokens.dart';
import '../../../../core/widgets/anchor_sheet.dart';
import '../../../../core/widgets/app_buttons.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../l10n/l10n.dart';
import 'text_formats.dart';

/// Picks any color: hue, saturation and lightness sliders, a preview and a
/// hex field. Gives a lowercase `#rrggbb`, or null when cancelled.
Future<String?> showColorPickerSheet(
  BuildContext context, {
  required String title,
  required String initialHex,
}) => showAnchorSheet<String>(
  context,
  semanticLabel: title,
  builder: (_) => ColorPickerSheet(title: title, initialHex: initialHex),
);

class ColorPickerSheet extends StatefulWidget {
  const ColorPickerSheet({
    super.key,
    required this.title,
    required this.initialHex,
  });

  final String title;

  /// The color to start from, `#rgb` or `#rrggbb`.
  final String initialHex;

  @override
  State<ColorPickerSheet> createState() => _ColorPickerSheetState();
}

class _ColorPickerSheetState extends State<ColorPickerSheet> {
  late Color _color =
      parseHexColor(widget.initialHex) ?? const Color(0xFFFEEA74);
  late HSLColor _hsl = HSLColor.fromColor(_color);
  late final _hex = TextEditingController(text: colorToHex(_color));
  bool _isHexValid = true;

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  void _setHsl(HSLColor hsl) {
    setState(() {
      _hsl = hsl;
      _color = hsl.toColor();
      _isHexValid = true;
      _hex.text = colorToHex(_color);
    });
  }

  void _typed(String text) {
    final color = parseHexColor(text);
    setState(() {
      _isHexValid = color != null;
      if (color == null) return;
      _color = color;
      final hsl = HSLColor.fromColor(color);
      // Greys have no hue of their own: the hue stays where it was.
      _hsl = hsl.saturation == 0 ? hsl.withHue(_hsl.hue) : hsl;
    });
  }

  void _apply() {
    if (!_isHexValid) return;
    Haptics.selection();
    Navigator.of(context).pop(colorToHex(_color));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.anchor;
    final density = context.density;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader(title: widget.title),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: density.space12,
              children: [
                Row(
                  spacing: 12,
                  children: [
                    Container(
                      key: const Key('color-picker-preview'),
                      width: density.control,
                      height: density.control,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _color,
                        borderRadius: context.appStyle.corners(
                          AnchorTokens.radius2xl,
                        ),
                        border: Border.all(color: colors.appBorder),
                      ),
                      child: ExcludeSemantics(
                        child: Text(
                          'Aa',
                          style: AppTypography.row.copyWith(
                            fontWeight: FontWeight.w600,
                            color: inkOn(_color),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: AppTextField(
                        key: const Key('color-picker-hex'),
                        controller: _hex,
                        icon: LucideIcons.hash,
                        hint: '#rrggbb',
                        error: _isHexValid ? null : l10n.colorPickerBadHex,
                        autocorrect: false,
                        textInputAction: TextInputAction.done,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp('[#0-9a-fA-F]'),
                          ),
                          LengthLimitingTextInputFormatter(7),
                        ],
                        onChanged: _typed,
                        onSubmitted: (_) => _apply(),
                      ),
                    ),
                  ],
                ),
                _GradientSlider(
                  key: const Key('color-picker-hue'),
                  label: l10n.colorPickerHue,
                  value: _hsl.hue,
                  max: 360,
                  colors: [
                    for (var h = 0; h <= 360; h += 60)
                      HSLColor.fromAHSL(1, h.toDouble(), 1, 0.5).toColor(),
                  ],
                  onChanged: (v) => _setHsl(_hsl.withHue(v)),
                ),
                _GradientSlider(
                  key: const Key('color-picker-saturation'),
                  label: l10n.colorPickerSaturation,
                  value: _hsl.saturation,
                  max: 1,
                  colors: [
                    _hsl.withSaturation(0).toColor(),
                    _hsl.withSaturation(1).toColor(),
                  ],
                  onChanged: (v) => _setHsl(_hsl.withSaturation(v)),
                ),
                _GradientSlider(
                  key: const Key('color-picker-lightness'),
                  label: l10n.colorPickerLightness,
                  value: _hsl.lightness,
                  max: 1,
                  colors: [
                    const Color(0xFF000000),
                    _hsl.withLightness(0.5).toColor(),
                    const Color(0xFFFFFFFF),
                  ],
                  onChanged: (v) => _setHsl(_hsl.withLightness(v)),
                ),
              ],
            ),
          ),
        ),
        SheetFooter(
          children: [
            AppButton(
              label: l10n.commonCancel,
              kind: AppButtonKind.secondary,
              onPressed: () => Navigator.of(context).pop(),
            ),
            AppButton(
              label: l10n.colorPickerApply,
              onPressed: _isHexValid ? _apply : null,
            ),
          ],
        ),
      ],
    );
  }
}

/// A slider over a gradient of what each of its values gives.
class _GradientSlider extends StatelessWidget {
  const _GradientSlider({
    super.key,
    required this.label,
    required this.value,
    required this.max,
    required this.colors,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double max;
  final List<Color> colors;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final anchor = context.anchor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            label,
            style: AppTypography.secondary.copyWith(color: anchor.appMuted),
          ),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 12,
            trackShape: _GradientTrack(colors, anchor.appBorder),
            thumbColor: AnchorTokens.colorControlKnob,
            overlayColor: anchor.appText.withValues(alpha: 0.08),
            thumbShape: const RoundSliderThumbShape(
              enabledThumbRadius: 12,
              elevation: 2,
            ),
            showValueIndicator: ShowValueIndicator.never,
          ),
          child: Slider(
            value: value.clamp(0, max),
            max: max,
            semanticFormatterCallback: (v) => '${(v / max * 100).round()}%',
            label: label,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

/// A rounded track filled with a gradient.
class _GradientTrack extends SliderTrackShape with BaseSliderTrackShape {
  const _GradientTrack(this.colors, this.edge);

  final List<Color> colors;
  final Color edge;

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isEnabled = false,
    bool isDiscrete = false,
    required TextDirection textDirection,
  }) {
    final rect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    final rounded = RRect.fromRectAndRadius(
      rect,
      Radius.circular(rect.height / 2),
    );
    context.canvas
      ..drawRRect(
        rounded,
        Paint()..shader = LinearGradient(colors: colors).createShader(rect),
      )
      ..drawRRect(
        rounded,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = edge,
      );
  }
}
