import 'dart:convert';

import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/core/widgets/editor/color_picker_sheet.dart';
import 'package:anchor/core/widgets/editor/editor_toolbar.dart';
import 'package:anchor/core/widgets/editor/text_formats.dart';
import 'package:anchor/core/widgets/quill_preview.dart';
import 'package:anchor/core/widgets/rich_text_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';

const _yellow = Color(0xFFFEEA74);
const _red = Color(0xFFE03131);

/// One run with all three formats, one highlighted in a custom colour, one
/// highlighted with an explicit text colour, and plain text.
final _formatted = jsonEncode({
  'ops': [
    {
      'insert': 'marked',
      'attributes': {
        'highlight': 'yellow',
        'color': '#e03131',
        'font': 'serif',
      },
    },
    {'insert': ' '},
    {
      'insert': 'custom',
      'attributes': {'highlight': '#112233'},
    },
    {'insert': ' '},
    {
      'insert': 'mono',
      'attributes': {'highlight': 'green', 'font': 'monospace'},
    },
    {'insert': ' plain\n'},
  ],
});

/// The style the text run [text] is drawn with, across every RichText.
TextStyle? spanStyle(WidgetTester tester, String text) {
  TextStyle? found;
  for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
    rich.text.visitChildren((span) {
      if (span is TextSpan && span.text == text) {
        found = span.style;
        return false;
      }
      return true;
    });
    if (found != null) break;
  }
  return found;
}

void main() {
  group('hex parsing', () {
    test('accepts #rgb and #rrggbb, with or without #, any case', () {
      expect(parseHexColor('#e03131'), _red);
      expect(parseHexColor('E03131'), _red);
      expect(parseHexColor('#A1b'), const Color(0xFFAA11BB));
      expect(parseHexColor('  #fff '), const Color(0xFFFFFFFF));
    });

    test('rejects anything else', () {
      for (final bad in [null, '', '#', '#12', '#1234', '#12345g', 'red']) {
        expect(parseHexColor(bad), isNull, reason: '$bad');
      }
    });

    test('normalises to lowercase #rrggbb', () {
      expect(normalizeHex('#A1B'), '#aa11bb');
      expect(normalizeHex('#E03131'), '#e03131');
      expect(colorToHex(const Color(0xFF0C8599)), '#0c8599');
      expect(normalizeHex('nope'), isNull);
    });
  });

  group('font values', () {
    test('every offered font is its own family; others are ignored', () {
      for (final (value, _) in fontOptions.skip(1)) {
        expect(fontFamilyValue(value), value);
      }
      expect(fontFamilyValue('comic'), 'comic');
      expect(fontFamilyValue('Comic Sans MS'), isNull);
      expect(fontFamilyValue(null), isNull);
    });
  });

  group('highlight values', () {
    test('presets and custom hex resolve to their fills', () {
      expect(highlightFill('yellow'), _yellow);
      expect(highlightFill('purple'), const Color(0xFFECCFFF));
      expect(highlightFill('#112233'), const Color(0xFF112233));
      expect(highlightFill('mauve'), isNull);
      expect(highlightFill(null), isNull);
    });

    test('ink keeps dark text, darkens light text, lightens on dark fills', () {
      const darkText = Color(0xFF222222);
      const lightText = Color(0xFFEEEEEE);
      expect(highlightInk(_yellow, darkText), darkText);
      expect(highlightInk(_yellow, lightText), highlightInkDark);
      expect(
        highlightInk(const Color(0xFF112233), darkText),
        highlightInkLight,
      );
      expect(highlightInk(const Color(0xFF112233), lightText), lightText);
    });
  });

  group('preview', () {
    Future<void> pumpPreview(WidgetTester tester, {bool dark = false}) {
      return tester.pumpWidget(
        MaterialApp(
          theme: dark ? ThemeData.dark() : ThemeData.light(),
          home: Scaffold(body: QuillPreview(content: _formatted)),
        ),
      );
    }

    testWidgets('shows highlight, text colour and font like the editor', (
      tester,
    ) async {
      await pumpPreview(tester);
      final marked = spanStyle(tester, 'marked')!;
      expect(marked.backgroundColor, _yellow);
      expect(marked.color, _red);
      expect(marked.fontFamily, 'serif');

      final custom = spanStyle(tester, 'custom')!;
      expect(custom.backgroundColor, const Color(0xFF112233));
      expect(custom.color, highlightInkLight);

      final mono = spanStyle(tester, 'mono')!;
      expect(mono.backgroundColor, const Color(0xFFAAF5B9));
      expect(mono.fontFamily, 'monospace');
      expect(find.text('marked custom mono plain'), findsOneWidget);
    });

    testWidgets('highlighted text gets dark ink in dark mode', (tester) async {
      await pumpPreview(tester, dark: true);
      expect(spanStyle(tester, 'mono')!.color, highlightInkDark);
      // An explicit colour still wins.
      expect(spanStyle(tester, 'marked')!.color, _red);
    });

    testWidgets('unformatted lines render as before', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuillPreview(
              content: jsonEncode({
                'ops': [
                  {'insert': '  spaced  \n'},
                ],
              }),
            ),
          ),
        ),
      );
      expect(find.text('spaced'), findsOneWidget);
    });
  });

  group('editor', () {
    Future<RichTextEditorState> pumpEditor(
      WidgetTester tester, {
      bool dark = false,
      String? highlightTerm,
      String? content,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: dark ? ThemeData.dark() : ThemeData.light(),
          localizationsDelegates:
              FlutterQuillLocalizations.localizationsDelegates,
          home: Scaffold(
            body: RichTextEditor(
              initialContent: content ?? _formatted,
              highlightTerm: highlightTerm,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return tester.state<RichTextEditorState>(find.byType(RichTextEditor));
    }

    testWidgets('paints highlight, text colour and font', (tester) async {
      await pumpEditor(tester);
      final marked = spanStyle(tester, 'marked')!;
      expect(marked.backgroundColor, _yellow);
      expect(marked.color, _red);
      expect(marked.fontFamily, 'serif');

      final custom = spanStyle(tester, 'custom')!;
      expect(custom.backgroundColor, const Color(0xFF112233));
      expect(custom.color, highlightInkLight);

      final mono = spanStyle(tester, 'mono')!;
      expect(mono.backgroundColor, const Color(0xFFAAF5B9));
      expect(mono.fontFamily, 'monospace');
      expect(spanStyle(tester, ' plain')?.backgroundColor, isNull);
    });

    testWidgets('highlighted text gets dark ink in dark mode', (tester) async {
      await pumpEditor(tester, dark: true);
      expect(spanStyle(tester, 'mono')!.color, highlightInkDark);
      expect(spanStyle(tester, 'marked')!.color, _red);
    });

    testWidgets('the toolbar palettes format the selection in the editor', (
      tester,
    ) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates:
              FlutterQuillLocalizations.localizationsDelegates,
          home: Scaffold(
            body: RichTextEditor(
              initialContent: '{"ops":[{"insert":"hello world\\n"}]}',
              focusNode: focusNode,
            ),
          ),
        ),
      );
      final state = tester.state<RichTextEditorState>(
        find.byType(RichTextEditor),
      );
      focusNode.requestFocus();
      await tester.pumpAndSettle();
      state.controller.updateSelection(
        const TextSelection(baseOffset: 6, extentOffset: 11),
        ChangeSource.local,
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byTooltip('Highlight colour'));
      await tester.tap(find.byTooltip('Highlight colour'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('swatch-custom')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('color-picker-hex')), '#F0F');
      await tester.pump();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      final ops = (jsonDecode(state.getContent()) as Map)['ops'];
      expect(ops, [
        {'insert': 'hello '},
        {
          'insert': 'world',
          'attributes': {'highlight': '#ff00ff'},
        },
        {'insert': '\n'},
      ]);
      expect(
        spanStyle(tester, 'world')!.backgroundColor,
        const Color(0xFFFF00FF),
      );
    });

    testWidgets('keeps the formats through a save', (tester) async {
      final state = await pumpEditor(tester);
      final ops = (jsonDecode(state.getContent()) as Map)['ops'] as List;
      expect(ops.first, {
        'insert': 'marked',
        'attributes': {
          'highlight': 'yellow',
          'color': '#e03131',
          'font': 'serif',
        },
      });
    });

    testWidgets('search marks still show, inside a highlight too', (
      tester,
    ) async {
      await pumpEditor(
        tester,
        highlightTerm: 'eg',
        content: jsonEncode({
          'ops': [
            {'insert': 'egg '},
            {
              'insert': 'legs',
              'attributes': {'highlight': 'yellow'},
            },
            {'insert': '\n'},
          ],
        }),
      );
      final plainHit = spanStyle(tester, 'eg')!;
      final hits = <TextStyle>[];
      for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
        rich.text.visitChildren((span) {
          if (span is TextSpan && span.text == 'eg') hits.add(span.style!);
          return true;
        });
      }
      expect(hits, hasLength(2));
      expect(plainHit.backgroundColor, isNotNull);
      // The match in the highlight is tinted, not plain yellow.
      final inHighlight = hits[1].backgroundColor!;
      expect(inHighlight, isNot(_yellow));
      expect(inHighlight, isNot(hits[0].backgroundColor));
      // The rest of the highlight keeps its fill.
      expect(spanStyle(tester, 's')!.backgroundColor, _yellow);
    });
  });

  group('toolbar', () {
    const ops = [
      {'insert': 'hello world\n'},
    ];

    Future<QuillController> pumpToolbar(WidgetTester tester) async {
      final controller = QuillController(
        document: Document.fromJson(ops),
        selection: const TextSelection(baseOffset: 0, extentOffset: 5),
      );
      addTearDown(controller.dispose);
      lastHighlight.value = 'yellow';
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates:
              FlutterQuillLocalizations.localizationsDelegates,
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: ListenableBuilder(
                listenable: controller,
                builder: (context, _) => EditorToolbar(
                  controller: controller,
                  state: EditorFormattingState.fromController(controller),
                ),
              ),
            ),
          ),
        ),
      );
      return controller;
    }

    List<dynamic> delta(QuillController c) => c.document.toDelta().toJson();

    List<dynamic> formatted(Map<String, dynamic> attributes) => [
      {'insert': 'hello', 'attributes': attributes},
      {'insert': ' world\n'},
    ];

    Future<void> tapTool(WidgetTester tester, String tooltip) async {
      await tester.ensureVisible(find.byTooltip(tooltip));
      await tester.tap(find.byTooltip(tooltip));
      await tester.pumpAndSettle();
    }

    Future<void> pick(WidgetTester tester, String key) async {
      await tester.tap(find.byKey(Key(key)));
      await tester.pumpAndSettle();
    }

    testWidgets('the highlighter applies the last colour and toggles off', (
      tester,
    ) async {
      final controller = await pumpToolbar(tester);
      await tapTool(tester, 'Highlight');
      expect(delta(controller), formatted({'highlight': 'yellow'}));

      await tapTool(tester, 'Remove highlight');
      expect(delta(controller), ops);
    });

    testWidgets('the highlight palette applies presets, custom and none', (
      tester,
    ) async {
      final controller = await pumpToolbar(tester);

      await tapTool(tester, 'Highlight colour');
      await pick(tester, 'swatch-green');
      expect(delta(controller), formatted({'highlight': 'green'}));
      expect(lastHighlight.value, 'green');
      // The one-tap button now shows and reuses green.
      final bar = tester.widget<Container>(
        find.byKey(const Key('Remove highlight-indicator')),
      );
      expect((bar.decoration! as BoxDecoration).color, const Color(0xFFAAF5B9));

      await tapTool(tester, 'Highlight colour');
      await pick(tester, 'swatch-custom');
      await tester.enterText(find.byKey(const Key('color-picker-hex')), '#A1B');
      await tester.pump();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(delta(controller), formatted({'highlight': '#aa11bb'}));
      expect(lastHighlight.value, '#aa11bb');

      await tapTool(tester, 'Highlight colour');
      await pick(tester, 'swatch-clear');
      expect(delta(controller), ops);

      await tapTool(tester, 'Highlight');
      expect(delta(controller), formatted({'highlight': '#aa11bb'}));
    });

    testWidgets('the text colour palette applies presets, custom and default', (
      tester,
    ) async {
      final controller = await pumpToolbar(tester);

      await tapTool(tester, 'Text colour');
      // Presets in the contract's order.
      final keys = tester
          .widgetList(
            find.byWidgetPredicate(
              (w) =>
                  w.key is ValueKey<String> &&
                  (w.key! as ValueKey<String>).value.startsWith('swatch-#'),
            ),
          )
          .map((w) => (w.key! as ValueKey<String>).value.substring(7))
          .toList();
      expect(keys, [
        '#e03131',
        '#e8590c',
        '#f08c00',
        '#2f9e44',
        '#0c8599',
        '#1971c2',
        '#7048e8',
        '#c2255c',
        '#868e96',
      ]);
      await pick(tester, 'swatch-#0c8599');
      expect(delta(controller), formatted({'color': '#0c8599'}));

      await tapTool(tester, 'Text colour');
      await pick(tester, 'swatch-custom');
      await tester.enterText(
        find.byKey(const Key('color-picker-hex')),
        '#ABCDEF',
      );
      await tester.pump();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(delta(controller), formatted({'color': '#abcdef'}));

      await tapTool(tester, 'Text colour');
      await pick(tester, 'swatch-clear');
      expect(delta(controller), ops);
    });

    testWidgets('cancelling the custom picker changes nothing', (tester) async {
      final controller = await pumpToolbar(tester);
      await tapTool(tester, 'Text colour');
      await pick(tester, 'swatch-custom');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(delta(controller), ops);
    });

    testWidgets('the font sheet applies serif, monospace and default', (
      tester,
    ) async {
      final controller = await pumpToolbar(tester);

      await tapTool(tester, 'Font');
      await pick(tester, 'font-serif');
      expect(delta(controller), formatted({'font': 'serif'}));

      await tapTool(tester, 'Font');
      await pick(tester, 'font-monospace');
      expect(delta(controller), formatted({'font': 'monospace'}));

      await tapTool(tester, 'Font');
      await pick(tester, 'font-default');
      expect(delta(controller), ops);
    });

    testWidgets('formats show as active on the toolbar', (tester) async {
      final controller = await pumpToolbar(tester);
      controller.formatSelection(TextFormats.color('#e03131'));
      await tester.pump();
      final bar = tester.widget<Container>(
        find.byKey(const Key('Text colour-indicator')),
      );
      expect((bar.decoration! as BoxDecoration).color, _red);
      final state = EditorFormattingState.fromController(controller);
      expect(state.textColor, '#e03131');
      expect(state.highlight, isNull);
    });
  });

  group('colour picker', () {
    Future<List<String?>> pumpPicker(
      WidgetTester tester,
      String? initial,
    ) async {
      final results = <String?>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) => FilledButton(
                onPressed: () async => results.add(
                  await ColorPickerSheet.show(
                    context,
                    title: 'Pick',
                    initialHex: initial,
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

    Color preview(WidgetTester tester) =>
        ((tester
                    .widget<Container>(
                      find.byKey(const Key('color-picker-preview')),
                    )
                    .decoration!
                as BoxDecoration)
            .color)!;

    testWidgets('starts from the given colour and applies it unchanged', (
      tester,
    ) async {
      final results = await pumpPicker(tester, '#E03131');
      expect(find.text('#e03131'), findsOneWidget);
      expect(preview(tester), _red);
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(results, ['#e03131']);
    });

    testWidgets('an invalid hex disables Apply until it is fixed', (
      tester,
    ) async {
      final results = await pumpPicker(tester, null);
      await tester.enterText(find.byKey(const Key('color-picker-hex')), '#12');
      await tester.pump();
      expect(find.text('Use #rgb or #rrggbb'), findsOneWidget);
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(results, isEmpty);

      await tester.enterText(find.byKey(const Key('color-picker-hex')), '#123');
      await tester.pump();
      expect(preview(tester), const Color(0xFF112233));
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(results, ['#112233']);
    });

    testWidgets('the sliders change the colour and the hex', (tester) async {
      await pumpPicker(tester, '#ff0000');
      final hue = find.descendant(
        of: find.byKey(const Key('color-picker-hue')),
        matching: find.byType(Slider),
      );
      tester.widget<Slider>(hue).onChanged!(120);
      await tester.pump();
      expect(preview(tester), const Color(0xFF00FF00));
      expect(find.text('#00ff00'), findsOneWidget);

      final lightness = find.descendant(
        of: find.byKey(const Key('color-picker-lightness')),
        matching: find.byType(Slider),
      );
      tester.widget<Slider>(lightness).onChanged!(1);
      await tester.pump();
      expect(find.text('#ffffff'), findsOneWidget);
    });

    testWidgets('cancel pops with nothing', (tester) async {
      final results = await pumpPicker(tester, '#e03131');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(results, [null]);
    });
  });
}
