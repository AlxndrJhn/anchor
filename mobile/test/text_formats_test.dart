import 'dart:io';

import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/core/theme/app_typography.dart';
import 'package:anchor/core/theme/tokens/anchor_tokens.dart';
import 'package:anchor/core/widgets/highlighted_text.dart';
import 'package:anchor/features/notes/domain/note_blocks.dart';
import 'package:anchor/features/notes/presentation/editor/color_picker_sheet.dart';
import 'package:anchor/features/notes/presentation/editor/text_formats.dart';
import 'package:anchor/features/notes/presentation/widgets/note_surface.dart';
import 'package:anchor/features/notes/presentation/widgets/note_text.dart';
import 'package:anchor/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _red = Color(0xFFE03131);

/// One run with all three formats, one on a light custom highlight, one on
/// a dark one, and plain text.
const _runs = [
  InlineRun('marked', highlight: 'yellow', color: '#e03131', font: 'serif'),
  InlineRun(' '),
  InlineRun('pale', highlight: '#ffee88'),
  InlineRun(' '),
  InlineRun('deep', highlight: '#112233', font: 'monospace'),
  InlineRun(' plain'),
];

/// The style of the span holding [text] in [span].
TextStyle? styleOf(InlineSpan span, String text) {
  TextStyle? found;
  span.visitChildren((child) {
    if (child is TextSpan && child.text == text) {
      found = child.style;
      return false;
    }
    return true;
  });
  return found;
}

void main() {
  group('hex colors', () {
    test('take #rgb and #rrggbb, with or without #, any case', () {
      expect(parseHexColor('#F0F'), const Color(0xFFFF00FF));
      expect(parseHexColor(' a1B2c3 '), const Color(0xFFA1B2C3));
      for (final bad in ['', '#ab', '#abcd', 'red', '#ggg', null]) {
        expect(parseHexColor(bad), isNull, reason: '$bad');
      }
      expect(normalizeHex('#ABC'), '#aabbcc');
      expect(colorToHex(const Color(0x80A1B2C3)), '#a1b2c3');
    });

    test('a custom highlight is a hex, a named one is not', () {
      expect(isCustomHighlight('#112233'), isTrue);
      expect(isCustomHighlight('yellow'), isFalse);
      expect(isCustomHighlight('#nope'), isFalse);
      expect(isCustomHighlight(null), isFalse);
    });

    test('ink on a custom highlight keeps the text when it reads', () {
      const dark = Color(0xFF2D3142);
      const light = Color(0xFFEAEAEA);
      expect(customHighlightInk(const Color(0xFFFFEE88), dark), isNull);
      expect(
        customHighlightInk(const Color(0xFFFFEE88), light),
        const Color(0xFF1A1A1A),
      );
      expect(
        customHighlightInk(const Color(0xFF112233), dark),
        const Color(0xFFFFFFFF),
      );
      expect(customHighlightInk(const Color(0xFF112233), light), isNull);
    });

    test('the text colors and fonts are the web app’s', () {
      final web = File(
        '../web/features/notes/text-style.ts',
      ).readAsStringSync();
      final hexes = RegExp(
        r'value: "(#[0-9a-f]{6})"',
      ).allMatches(web).map((m) => m.group(1)).toList();
      expect([for (final color in TextColor.values) color.hex], hexes);
      for (final font in TextFont.values) {
        expect(web, contains('value: "${font.value}"'));
      }
      expect(TextFont.of('serif')!.family, AppTypography.serif);
      expect(TextFont.of('monospace')!.family, AppTypography.mono);
      expect(TextFont.of('cursive'), isNull);
    });

    test('a note’s runs keep their color and font', () {
      final blocks = parseNoteBlocks(
        '{"ops":[{"insert":"hi","attributes":{"color":"#e03131",'
        '"font":"serif","highlight":"#112233"}},{"insert":"\\n"}]}',
      );
      final run = blocks.single.runs.single;
      expect(run.color, '#e03131');
      expect(run.font, 'serif');
      expect(run.highlight, '#112233');
    });
  });

  group('cards', () {
    Future<(InlineSpan, List<HighlightRange>)> spanIn(
      WidgetTester tester, {
      bool dark = false,
    }) async {
      late (InlineSpan, List<HighlightRange>) result;
      await tester.pumpWidget(
        MaterialApp(
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          home: Builder(
            builder: (context) {
              result = spanOfRuns(
                context,
                _runs,
                style: const TextStyle(fontSize: 14),
                appearance: NoteAppearance.of(context, null),
              );
              return const SizedBox();
            },
          ),
        ),
      );
      return result;
    }

    testWidgets('show text color, font and custom highlights', (tester) async {
      final (span, marks) = await spanIn(tester);
      final marked = styleOf(span, 'marked')!;
      expect(marked.color, _red);
      expect(marked.fontFamily, AppTypography.serif);
      expect(styleOf(span, 'deep')!.fontFamily, AppTypography.mono);
      // Dark text reads on the pale highlight; white goes on the deep one.
      expect(styleOf(span, 'pale')!.color, isNull);
      expect(styleOf(span, 'deep')!.color, const Color(0xFFFFFFFF));
      expect(styleOf(span, ' plain')!.color, isNull);

      expect(
        [for (final mark in marks) mark.color],
        [
          AnchorColors.light.highlights['yellow']!.fill,
          const Color(0xFFFFEE88),
          const Color(0xFF112233),
        ],
      );
    });

    testWidgets('in dark mode, light text gets dark ink on a pale highlight', (
      tester,
    ) async {
      final (span, _) = await spanIn(tester, dark: true);
      expect(styleOf(span, 'pale')!.color, const Color(0xFF1A1A1A));
      expect(styleOf(span, 'deep')!.color, isNull);
      // An explicit color still wins.
      expect(styleOf(span, 'marked')!.color, _red);
    });
  });

  group('color picker', () {
    Future<List<String?>> openPicker(
      WidgetTester tester, {
      String initialHex = '#e03131',
    }) async {
      final results = <String?>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async => results.add(
                  await showColorPickerSheet(
                    context,
                    title: 'Custom text color',
                    initialHex: initialHex,
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      return results;
    }

    Finder hexField() => find.descendant(
      of: find.byKey(const Key('color-picker-hex')),
      matching: find.byType(TextField),
    );

    Color preview(WidgetTester tester) =>
        (tester
                    .widget<Container>(
                      find.byKey(const Key('color-picker-preview')),
                    )
                    .decoration!
                as BoxDecoration)
            .color!;

    testWidgets('starts from the given color and applies it unchanged', (
      tester,
    ) async {
      final results = await openPicker(tester, initialHex: '#ABC');
      expect(tester.widget<TextField>(hexField()).controller!.text, '#aabbcc');
      expect(preview(tester), const Color(0xFFAABBCC));
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(results, ['#aabbcc']);
    });

    testWidgets('a bad hex rests Apply until it is fixed', (tester) async {
      final results = await openPicker(tester);
      await tester.enterText(hexField(), '#12');
      await tester.pump();
      expect(find.text('Use #rgb or #rrggbb'), findsOneWidget);
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(results, isEmpty);

      await tester.enterText(hexField(), '#F0F');
      await tester.pump();
      expect(preview(tester), const Color(0xFFFF00FF));
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(results, ['#ff00ff']);
    });

    testWidgets('the sliders change the color and the hex', (tester) async {
      await openPicker(tester, initialHex: '#ff0000');
      final hue = find.descendant(
        of: find.byKey(const Key('color-picker-hue')),
        matching: find.byType(Slider),
      );
      await tester.tap(hue); // the middle: 180°, cyan
      await tester.pump();
      expect(preview(tester), const Color(0xFF00FFFF));
      expect(tester.widget<TextField>(hexField()).controller!.text, '#00ffff');
    });

    testWidgets('Cancel gives nothing', (tester) async {
      final results = await openPicker(tester);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(results, [null]);
    });
  });
}
