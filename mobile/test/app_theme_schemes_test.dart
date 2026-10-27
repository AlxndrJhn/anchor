import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/core/theme/tokens/app_dimensions.dart';
import 'package:anchor/core/theme/tokens/app_schemes.dart';
import 'package:anchor/core/theme/tokens/app_style.dart';
import 'package:anchor/features/notes/presentation/widgets/note_background.dart';
import 'package:flutter/material.dart';
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

  test('OLED is pure black in dark mode, and its cards keep an outline', () {
    final oled = schemeById('oled')!;
    expect(oled.name, 'OLED');
    expect(oled.dark.background, const Color(0xFF000000));
    expect(oled.dark.sidebar, const Color(0xFF000000));
    expect(oled.dark.card, isNot(oled.dark.background));

    final dark = AppTheme.dark(DisplayDensity.standard, 'oled');
    expect(dark.scaffoldBackgroundColor, const Color(0xFF000000));
    expect(dark.colorScheme.onSurface, const Color(0xFFFFFFFF));
    final tokens = dark.extension<AppStyleTokens>()!;
    expect(tokens.cardSide.color, oled.dark.border);
    expect(tokens.noteFill, oled.dark.card);
    // High contrast: white on black, and the muted text still past AA.
    expect(
      _contrast(oled.dark.mutedForeground, oled.dark.background),
      greaterThan(7),
    );

    // Its light side is Anchor's light, and keeps Anchor's borderless cards.
    final light = AppTheme.light(DisplayDensity.standard, 'oled');
    expect(light.extension<AppStyleTokens>()!.cardSide, BorderSide.none);
  });

  testWidgets(
    'on OLED a plain note is a near-black card; coloured notes keep theirs',
    (tester) async {
      final oled = schemeById('oled')!;
      late Color plain, red;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(DisplayDensity.standard, 'oled'),
          home: Builder(
            builder: (context) {
              plain = NoteBackground.resolveColor(context, null);
              red = NoteBackground.resolveColor(
                context,
                NoteBackgroundStyle.colorRed,
              );
              return const SizedBox();
            },
          ),
        ),
      );
      expect(plain, oled.dark.card);
      expect(red, const Color(0xFF331D21));
      // Both stand off the black page.
      expect(_contrast(red, oled.dark.background), greaterThan(1.2));
    },
  );

  test("Gruvbox's dark side is true Gruvbox dark", () {
    final dark = schemeById('gruvbox')!.dark;
    expect(dark.background, const Color(0xFF282828)); // bg
    expect(dark.card, const Color(0xFF3C3836)); // bg1
    expect(dark.sidebar, const Color(0xFF1D2021)); // bg0_h
    expect(dark.muted, const Color(0xFF504945)); // bg2
    expect(dark.foreground, const Color(0xFFEBDBB2)); // fg
    expect(dark.mutedForeground, const Color(0xFFBDAE93)); // fg3
    expect(dark.accent, const Color(0xFFFE8019)); // bright orange
    expect(dark.accentInk, const Color(0xFFFABD2F)); // bright yellow
    expect(dark.destructive, const Color(0xFFFB4934)); // bright red
  });
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}
