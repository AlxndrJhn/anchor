import 'dart:convert';

import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/core/theme/tokens/anchor_tokens.dart';
import 'package:anchor/features/notes/presentation/editor/editor_palette.dart';
import 'package:anchor/features/notes/presentation/editor/rich_text_editor.dart';
import 'package:anchor/features/notes/presentation/widgets/card_body.dart';
import 'package:anchor/features/notes/presentation/widgets/note_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';

final _plain = AnchorColors.light.notes['none']!;

final _palette = EditorPalette(
  muted: _plain.muted,
  surface: _plain.surface,
  border: _plain.border,
  background: _plain.bg,
  highlightFill: (name) => AnchorColors.light.highlights[name]!.fill,
  highlightInk: (name) => AnchorColors.light.highlights[name]!.ink!,
);

const _hebrew = 'שלום עולם (בעברית).';
const _arabic = 'مرحبا بالعالم!';
const _english = 'Back to English.';
const _item = 'חלב';

/// No direction attribute anywhere: as notes come from the web and sync.
final _note = jsonEncode({
  'ops': [
    {'insert': 'Shopping list.\n$_hebrew\n$_arabic\n$_english\n$_item'},
    {
      'insert': '\n',
      'attributes': {'list': 'unchecked'},
    },
  ],
});

void main() {
  test('a paragraph takes its direction from its first strong character', () {
    expect(paragraphDirection(_hebrew), TextDirection.rtl);
    expect(paragraphDirection('2. $_arabic'), TextDirection.rtl);
    expect(paragraphDirection('(1) $_english $_hebrew'), TextDirection.ltr);
    expect(paragraphDirection('🙂 $_hebrew'), TextDirection.rtl);
    expect(paragraphDirection('۱۲ Persian digits'), TextDirection.ltr);
    expect(paragraphDirection('Σημείωση'), TextDirection.ltr);
    expect(paragraphDirection('42 🙂'), isNull);
  });

  testWidgets('the editor lays out each line in its own direction', (
    tester,
  ) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates:
            FlutterQuillLocalizations.localizationsDelegates,
        home: Scaffold(
          body: SingleChildScrollView(
            controller: scroll,
            child: RichTextEditor(
              initialContent: _note,
              focusNode: focus,
              canEdit: true,
              scrollController: scroll,
              palette: _palette,
              sortChecklistItems: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    RenderParagraph line(String text) => tester.renderObject(
      find
          .descendant(
            of: find.byType(QuillEditor),
            matching: find.text(text, findRichText: true),
          )
          .first,
    );
    Rect letters(String text) {
      final paragraph = line(text);
      return paragraph
          .getBoxesForSelection(
            TextSelection(baseOffset: 0, extentOffset: text.length),
          )
          .map((b) => b.toRect())
          .reduce((a, b) => a.expandToInclude(b))
          .shift(paragraph.localToGlobal(Offset.zero));
    }

    final editor = tester.getRect(find.byType(QuillEditor));
    for (final (text, direction) in [
      (_hebrew, TextDirection.rtl),
      (_arabic, TextDirection.rtl),
      (_english, TextDirection.ltr),
      (_item, TextDirection.rtl),
    ]) {
      expect(line(text).textDirection, direction, reason: text);
      final box = letters(text);
      // Right-to-left lines end near the right edge, the others start near
      // the left one.
      if (direction == TextDirection.rtl) {
        expect(editor.right - box.right, lessThan(editor.width / 4));
        expect(box.left - editor.left, greaterThan(editor.width / 4));
      } else {
        expect(box.left - editor.left, lessThan(editor.width / 4));
      }
    }
    // The Hebrew item's checkbox sits at its right, apart from its text.
    final checkbox = tester.getRect(
      find.byWidgetPredicate(
        (w) => w is AnimatedContainer && w.constraints?.maxWidth == 22,
      ),
    );
    expect(checkbox.left - letters(_item).right, greaterThan(4));
    expect(editor.right - checkbox.right, lessThan(16));

    // A tap on it ticks the item.
    await tester.tapAt(checkbox.center);
    await tester.pump();
    final controller = tester
        .widget<QuillEditor>(find.byType(QuillEditor))
        .controller;
    expect(
      jsonEncode(controller.document.toDelta().toJson()),
      contains('"list":"checked"'),
    );
  });

  testWidgets('a card shows each line in its own direction', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 300,
              child: Builder(
                builder: (context) => CardBody(
                  content: _note,
                  appearance: NoteAppearance.of(context, null),
                  layout: CardLayout.masonry,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final card = tester.getRect(find.byType(CardBody));
    Rect lineOf(String text) =>
        tester.getRect(find.text(text, findRichText: true).first);
    TextDirection directionOf(String text) => tester
        .renderObject<RenderParagraph>(
          find.text(text, findRichText: true).first,
        )
        .textDirection;

    expect(directionOf(_hebrew), TextDirection.rtl);
    expect(directionOf(_arabic), TextDirection.rtl);
    expect(directionOf(_english), TextDirection.ltr);
    expect(lineOf(_hebrew).right, closeTo(card.right, 1));
    expect(lineOf(_arabic).right, closeTo(card.right, 1));
    expect(lineOf(_english).left, closeTo(card.left, 1));
    // A checklist item's box sits at the start: the right, for Hebrew.
    expect(lineOf(_item).left, closeTo(card.left, 1));
    expect(lineOf(_item).right, closeTo(card.right - 21, 1));
  });
}
