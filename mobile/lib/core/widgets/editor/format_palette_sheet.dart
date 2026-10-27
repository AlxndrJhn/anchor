import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/context_extensions.dart';
import '../../theme/tokens/app_icon_sizes.dart';
import '../../theme/tokens/app_opacity.dart';
import '../../theme/tokens/app_radius.dart';
import '../app_bottom_sheet.dart';
import 'text_formats.dart';

/// What was picked in a [FormatPaletteSheet].
sealed class PaletteChoice {
  const PaletteChoice();
}

/// A preset, by its stored value.
class PresetChoice extends PaletteChoice {
  final String value;
  const PresetChoice(this.value);
}

/// "Custom…": open the colour picker.
class CustomChoice extends PaletteChoice {
  const CustomChoice();
}

/// "None" / "Default": remove the format.
class ClearChoice extends PaletteChoice {
  const ClearChoice();
}

/// A swatch offered by a [FormatPaletteSheet].
class PaletteSwatch {
  /// The value stored when it's picked.
  final String value;
  final String label;
  final Color color;

  const PaletteSwatch(this.value, this.label, this.color);
}

/// A sheet of colour swatches plus "Custom…" and a clear option.
class FormatPaletteSheet extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<PaletteSwatch> swatches;

  /// The selection's current value, marked with a tick.
  final String? current;
  final String clearLabel;

  /// Draws swatches as highlights behind sample text, rather than as text
  /// in the colour.
  final bool asHighlight;

  const FormatPaletteSheet({
    super.key,
    required this.title,
    required this.icon,
    required this.swatches,
    required this.clearLabel,
    this.current,
    this.asHighlight = false,
  });

  static Future<PaletteChoice?> show(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<PaletteSwatch> swatches,
    required String clearLabel,
    String? current,
    bool asHighlight = false,
  }) {
    return AppBottomSheet.show<PaletteChoice>(
      context,
      builder: (_) => FormatPaletteSheet(
        title: title,
        icon: icon,
        swatches: swatches,
        clearLabel: clearLabel,
        current: current,
        asHighlight: asHighlight,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dims = context.dims;
    final isCustom =
        current != null && !swatches.any((s) => s.value == current);
    final customColor = isCustom ? parseHexColor(current) : null;

    return AppBottomSheet(
      icon: icon,
      iconColor: theme.colorScheme.tertiary,
      title: title,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(dims.xl, 0, dims.xl, dims.lg),
        child: Wrap(
          spacing: dims.sm,
          runSpacing: dims.sm,
          children: [
            for (final swatch in swatches)
              _SwatchTile(
                key: Key('swatch-${swatch.value}'),
                label: swatch.label,
                selected: swatch.value == current,
                child: _sample(context, swatch.color),
                onTap: () => Navigator.pop(context, PresetChoice(swatch.value)),
              ),
            _SwatchTile(
              key: const Key('swatch-custom'),
              label: 'Custom…',
              selected: isCustom,
              onTap: () => Navigator.pop(context, const CustomChoice()),
              child: customColor != null
                  ? _sample(context, customColor)
                  : Icon(
                      LucideIcons.plus,
                      size: AppIconSizes.md,
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: AppOpacity.secondary,
                      ),
                    ),
            ),
            _SwatchTile(
              key: const Key('swatch-clear'),
              label: clearLabel,
              selected: current == null,
              onTap: () => Navigator.pop(context, const ClearChoice()),
              child: Icon(
                LucideIcons.ban,
                size: AppIconSizes.md,
                color: theme.colorScheme.onSurface.withValues(
                  alpha: AppOpacity.secondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sample(BuildContext context, Color color) {
    final theme = Theme.of(context);
    final style = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
    );
    if (asHighlight) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: color,
        alignment: Alignment.center,
        child: Text(
          'Aa',
          style: style?.copyWith(
            color: highlightInk(color, theme.colorScheme.onSurface),
          ),
        ),
      );
    }
    return Text('Aa', style: style?.copyWith(color: color));
  }
}

class _SwatchTile extends StatelessWidget {
  final String label;
  final bool selected;
  final Widget child;
  final VoidCallback onTap;

  const _SwatchTile({
    super.key,
    required this.label,
    required this.selected,
    required this.child,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.tertiary;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.smBorder,
        child: SizedBox(
          width: 64,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 40,
                clipBehavior: Clip.antiAlias,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: AppRadius.xsBorder,
                  border: Border.all(
                    color: selected
                        ? accent
                        : theme.colorScheme.outline.withValues(
                            alpha: AppOpacity.border,
                          ),
                    width: selected ? 2 : 1,
                  ),
                ),
                child: child,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: selected
                      ? accent
                      : theme.colorScheme.onSurface.withValues(
                          alpha: AppOpacity.secondary,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A sheet of the font choices, each shown in its own font. Pops with the
/// chosen [fontOptions] entry's value wrapped in a record (null = default).
class FontPickerSheet extends StatelessWidget {
  final String? current;

  const FontPickerSheet({super.key, this.current});

  static Future<(String?,)?> show(BuildContext context, {String? current}) {
    return AppBottomSheet.show<(String?,)>(
      context,
      builder: (_) => FontPickerSheet(current: current),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dims = context.dims;
    return AppBottomSheet(
      icon: LucideIcons.type,
      iconColor: theme.colorScheme.tertiary,
      title: 'Font',
      child: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: dims.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (value, label) in fontOptions)
              ListTile(
                key: Key('font-${value ?? 'default'}'),
                contentPadding: EdgeInsets.symmetric(horizontal: dims.xl),
                title: Text(
                  label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontFamily: value,
                  ),
                ),
                trailing: value == current
                    ? Icon(
                        LucideIcons.check,
                        size: AppIconSizes.md,
                        color: theme.colorScheme.tertiary,
                      )
                    : null,
                selected: value == current,
                onTap: () => Navigator.pop(context, (value,)),
              ),
          ],
        ),
      ),
    );
  }
}
