import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/context_extensions.dart';
import '../../theme/tokens/app_icon_sizes.dart';
import '../../theme/tokens/app_opacity.dart';
import '../../theme/tokens/app_radius.dart';
import '../app_bottom_sheet.dart';
import 'text_formats.dart';

/// A small custom colour picker: hue, saturation and lightness sliders, a
/// preview swatch and a hex field. Pops with a lowercase `#rrggbb`, or null
/// when cancelled.
class ColorPickerSheet extends StatefulWidget {
  final String title;

  /// The colour to start from, `#rgb` or `#rrggbb`.
  final String? initialHex;

  const ColorPickerSheet({super.key, required this.title, this.initialHex});

  static Future<String?> show(
    BuildContext context, {
    required String title,
    String? initialHex,
  }) {
    return AppBottomSheet.show<String>(
      context,
      builder: (_) => ColorPickerSheet(title: title, initialHex: initialHex),
    );
  }

  @override
  State<ColorPickerSheet> createState() => _ColorPickerSheetState();
}

class _ColorPickerSheetState extends State<ColorPickerSheet> {
  late HSLColor _hsl;

  /// The exact colour; kept apart from [_hsl] so a typed hex survives the
  /// HSL round trip unchanged.
  late Color _color;
  late final TextEditingController _hexController;
  bool _hexValid = true;

  @override
  void initState() {
    super.initState();
    _color = parseHexColor(widget.initialHex) ?? highlightPresets.first.color;
    _hsl = HSLColor.fromColor(_color);
    _hexController = TextEditingController(text: colorToHex(_color));
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  void _setHsl(HSLColor hsl) {
    setState(() {
      _hsl = hsl;
      _color = hsl.toColor();
      _hexValid = true;
      _hexController.text = colorToHex(_color);
    });
  }

  void _onHexChanged(String text) {
    final color = parseHexColor(text);
    setState(() {
      _hexValid = color != null;
      if (color != null) {
        _color = color;
        final hsl = HSLColor.fromColor(color);
        // Greys have no hue of their own; keep the slider where it was.
        _hsl = hsl.saturation == 0 ? hsl.withHue(_hsl.hue) : hsl;
      }
    });
  }

  void _apply() {
    if (!_hexValid) return;
    Navigator.pop(context, colorToHex(_color));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dims = context.dims;
    final hue = _hsl.hue;

    return AppBottomSheet(
      avoidKeyboard: true,
      icon: LucideIcons.palette,
      iconColor: theme.colorScheme.tertiary,
      title: widget.title,
      trailing: IconButton(
        icon: const Icon(LucideIcons.x, size: AppIconSizes.md),
        tooltip: 'Close',
        color: theme.colorScheme.onSurface.withValues(
          alpha: AppOpacity.secondary,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(dims.xl, 0, dims.xl, dims.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  key: const Key('color-picker-preview'),
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: _color,
                    borderRadius: AppRadius.smBorder,
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(
                        alpha: AppOpacity.border,
                      ),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Aa',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: highlightInk(_color, null),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(width: dims.md),
                Expanded(
                  child: TextField(
                    key: const Key('color-picker-hex'),
                    controller: _hexController,
                    onChanged: _onHexChanged,
                    onSubmitted: (_) => _apply(),
                    textInputAction: TextInputAction.done,
                    autocorrect: false,
                    enableSuggestions: false,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp('[#0-9a-fA-F]')),
                      LengthLimitingTextInputFormatter(7),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Hex',
                      hintText: '#rrggbb',
                      errorText: _hexValid ? null : 'Use #rgb or #rrggbb',
                      prefixIcon: const Icon(LucideIcons.hash, size: 18),
                      border: OutlineInputBorder(
                        borderRadius: AppRadius.buttonBorder,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: dims.md),
            _GradientSlider(
              key: const Key('color-picker-hue'),
              label: 'Hue',
              value: hue,
              max: 360,
              colors: [
                for (var h = 0; h <= 360; h += 60)
                  HSLColor.fromAHSL(1, h.toDouble(), 1, 0.5).toColor(),
              ],
              onChanged: (v) => _setHsl(_hsl.withHue(v)),
            ),
            _GradientSlider(
              key: const Key('color-picker-saturation'),
              label: 'Saturation',
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
              label: 'Lightness',
              value: _hsl.lightness,
              max: 1,
              colors: [
                Colors.black,
                _hsl.withLightness(0.5).toColor(),
                Colors.white,
              ],
              onChanged: (v) => _setHsl(_hsl.withLightness(v)),
            ),
            SizedBox(height: dims.md),
            SheetActionButtons(
              confirmText: 'Apply',
              onConfirm: _hexValid ? _apply : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// A slider over a gradient track showing what each value gives.
class _GradientSlider extends StatelessWidget {
  final String label;
  final double value;
  final double max;
  final List<Color> colors;
  final ValueChanged<double> onChanged;

  const _GradientSlider({
    super.key,
    required this.label,
    required this.value,
    required this.max,
    required this.colors,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outline = theme.colorScheme.outline.withValues(
      alpha: AppOpacity.border,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(
              alpha: AppOpacity.secondary,
            ),
          ),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 12,
            trackShape: _GradientTrackShape(colors, outline),
            thumbColor: Colors.white,
            overlayColor: theme.colorScheme.onSurface.withValues(
              alpha: AppOpacity.subtleFill,
            ),
            thumbShape: const RoundSliderThumbShape(
              enabledThumbRadius: 10,
              elevation: 2,
            ),
            showValueIndicator: ShowValueIndicator.never,
          ),
          child: Slider(
            value: value.clamp(0, max),
            max: max,
            semanticFormatterCallback: (v) => '$label ${v.round()}',
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

/// A rounded track filled with a horizontal gradient.
class _GradientTrackShape extends SliderTrackShape with BaseSliderTrackShape {
  final List<Color> colors;
  final Color outline;

  const _GradientTrackShape(this.colors, this.outline);

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
    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(rect.height / 2),
    );
    context.canvas
      ..drawRRect(
        rrect,
        Paint()..shader = LinearGradient(colors: colors).createShader(rect),
      )
      ..drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = outline,
      );
  }
}
