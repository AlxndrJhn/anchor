import 'dart:convert';

import 'package:anchor/core/widgets/quill_preview.dart';
import 'package:anchor/core/widgets/rich_text_editor.dart';
import 'package:anchor/features/notes/domain/inline_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _picture(String id, {double? width, String? caption}) => {
  'insert': {
    InlineImage.embedType: InlineImage(
      id: id,
      width: width,
      caption: caption,
    ).encode(),
  },
};

/// Draws a picture as a box, without the attachment behind it.
class _BoxBuilder extends EmbedBuilder {
  const _BoxBuilder();

  @override
  String get key => InlineImage.embedType;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) =>
      const SizedBox(height: 40, child: Placeholder());
}

void main() {
  group('InlineImage', () {
    test('keeps its attachment, width and caption', () {
      final image = InlineImage.tryParse(
        const InlineImage(id: 'a', width: 0.5, caption: 'Cat').encode(),
      )!;
      expect(image.id, 'a');
      expect(image.width, 0.5);
      expect(image.caption, 'Cat');
    });

    test('reads the web app’s embed, and drops what it can’t use', () {
      final image = InlineImage.tryParse(
        jsonEncode({'id': 'a', 'width': 4, 'caption': '  '}),
      )!;
      expect(image.width, isNull);
      expect(image.caption, isNull);
      expect(InlineImage.tryParse('nope'), isNull);
      expect(InlineImage.tryParse(jsonEncode({'width': 1})), isNull);
    });

    test('a full-width picture without a caption stores just its id', () {
      expect(jsonDecode(const InlineImage(id: 'a').encode()), {'id': 'a'});
    });

    test('lists the attachments the text shows', () {
      final content = jsonEncode({
        'ops': [
          {'insert': 'Hi\n'},
          _picture('a'),
          {'insert': '\n'},
          _picture('b', width: 0.3),
          {'insert': '\n'},
        ],
      });
      expect(inlineImageIds(content), {'a', 'b'});
      expect(inlineImageIds('{"ops":[{"insert":"x\\n"}]}'), isEmpty);
      expect(inlineImageIds(null), isEmpty);
    });
  });

  group('putting pictures in the text', () {
    Future<RichTextEditorState> pumpEditor(
      WidgetTester tester,
      List<Map<String, Object?>> ops,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates:
              FlutterQuillLocalizations.localizationsDelegates,
          home: Scaffold(
            body: RichTextEditor(
              initialContent: jsonEncode({'ops': ops}),
              embedBuilders: const [_BoxBuilder()],
            ),
          ),
        ),
      );
      await tester.pump();
      return tester.state<RichTextEditorState>(find.byType(RichTextEditor));
    }

    List<Object?> ops(RichTextEditorState editor) =>
        (jsonDecode(editor.getContent()) as Map)['ops'] as List<Object?>;

    BlockEmbed embed(String id) =>
        BlockEmbed(InlineImage.embedType, InlineImage(id: id).encode());

    testWidgets('mid-line, the line is split around the picture', (
      tester,
    ) async {
      final editor = await pumpEditor(tester, [
        {'insert': 'abcdef\n'},
      ]);

      editor.insertBlockEmbeds([embed('a')], offset: 3);

      expect(ops(editor), [
        {'insert': 'abc\n'},
        _picture('a'),
        {'insert': '\ndef\n'},
      ]);
      expect(editor.controller.selection.baseOffset, 6);
      expect(editor.embedsOf(InlineImage.embedType), [
        InlineImage(id: 'a').encode(),
      ]);
    });

    testWidgets('at a line’s start, each picture gets a line of its own', (
      tester,
    ) async {
      final editor = await pumpEditor(tester, [
        {'insert': 'abc\n'},
      ]);

      editor.insertBlockEmbeds([embed('a'), embed('b')], offset: 0);

      expect(ops(editor), [
        _picture('a'),
        {'insert': '\n'},
        _picture('b'),
        {'insert': '\nabc\n'},
      ]);
    });

    testWidgets('the checklist item before the picture stays one', (
      tester,
    ) async {
      final editor = await pumpEditor(tester, [
        {'insert': 'milk'},
        {
          'insert': '\n',
          'attributes': {'list': 'unchecked'},
        },
      ]);

      editor.insertBlockEmbeds([embed('a')], offset: 4);

      final content = ops(editor);
      expect(content.first, {'insert': 'milk'});
      expect(content[1], {
        'insert': '\n',
        'attributes': {'list': 'unchecked'},
      });
      expect(content[2], _picture('a'));
      expect(content[3], {'insert': '\n'});
    });

    testWidgets('one undo takes the pictures out again', (tester) async {
      final editor = await pumpEditor(tester, [
        {'insert': 'abc\n'},
      ]);

      editor.insertBlockEmbeds([embed('a'), embed('b')], offset: 1);
      editor.controller.undo();

      expect(ops(editor), [
        {'insert': 'abc\n'},
      ]);
    });
  });

  group('note cards', () {
    testWidgets('a picture’s line shows nothing, and items keep their line', (
      tester,
    ) async {
      int? toggled;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuillPreview(
              content: jsonEncode({
                'ops': [
                  _picture('a'),
                  {'insert': '\n'},
                  {'insert': 'milk'},
                  {
                    'insert': '\n',
                    'attributes': {'list': 'unchecked'},
                  },
                ],
              }),
              onToggleItem: (line) => toggled = line,
            ),
          ),
        ),
      );

      expect(find.text('milk'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Tick milk'));
      expect(toggled, 1);
    });

    test('plain text leaves the pictures out', () {
      final content = jsonEncode({
        'ops': [
          {'insert': 'Hi\n'},
          _picture('a'),
          {'insert': '\nthere\n'},
        ],
      });
      expect(extractPlainTextFromQuillContent(content), 'Hi\nthere');
    });
  });
}
