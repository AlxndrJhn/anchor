import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/core/theme/tokens/app_dimensions.dart';
import 'package:anchor/core/theme/tokens/app_schemes.dart';
import 'package:anchor/core/theme/tokens/app_style.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('style ids round-trip and fall back to Default', () {
    for (final style in AppStyle.values) {
      expect(AppStyle.fromId(style.id), style);
    }
    expect(AppStyle.fromId('nope'), AppStyle.standard);
    expect(AppStyle.fromId(null), AppStyle.standard);
  });

  test('every scheme id is unique and found', () {
    final ids = appSchemes.map((s) => s.id).toSet();
    expect(ids.length, appSchemes.length);
    expect(ids, isNot(contains(anchorSchemeId)));
    for (final id in ids) {
      expect(schemeById(id)?.id, id);
    }
  });

  test('a scheme colours the theme; Lo-fi uses its own greys', () {
    final nord = schemeById('nord')!;
    final theme = AppTheme.dark(DisplayDensity.standard, 'nord');
    expect(theme.scaffoldBackgroundColor, nord.dark.background);
    expect(theme.colorScheme.onSurface, nord.dark.foreground);

    final lofi = AppTheme.light(DisplayDensity.standard, 'nord', AppStyle.lofi);
    expect(lofi.scaffoldBackgroundColor, lofiScheme.light.background);
    expect(lofi.extension<AppStyleTokens>()!.plainNotes, isTrue);
  });

  test('Anchor with Default keeps the original look', () {
    final theme = AppTheme.light();
    final tokens = theme.extension<AppStyleTokens>()!;
    expect(tokens.style, AppStyle.standard);
    expect(tokens.cardShadows, isEmpty);
    expect(tokens.noteFill, isNull);
  });

  test('Neo-Brutalism draws ink outlines and a hard shadow', () {
    final theme = AppTheme.light(
      DisplayDensity.standard,
      'dracula',
      AppStyle.neoBrutalism,
    );
    final tokens = theme.extension<AppStyleTokens>()!;
    final ink = schemeById('dracula')!.light.foreground;
    expect(tokens.cardSide.color, ink);
    expect(tokens.cardShadows.single.blurRadius, 0);
  });
}
