import 'dart:convert';

import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/core/theme/display_density.dart';
import 'package:anchor/core/theme/note_typography.dart';
import 'package:anchor/core/theme/tokens/anchor_tokens.dart';
import 'package:anchor/features/notes/presentation/editor/block_spacing.dart';
import 'package:anchor/features/notes/presentation/editor/editor_palette.dart';
import 'package:anchor/features/notes/presentation/editor/list_markers.dart';
import 'package:anchor/features/notes/presentation/editor/rich_text_editor.dart';
import 'package:flutter/material.dart';
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

Map<String, Object> _line(String text, [Map<String, Object>? attributes]) => {
  'insert': text,
  'attributes': ?attributes,
};

final _note = jsonEncode({
  'ops': [
    {'insert': 'Five days in Lisbon\n'},
    {'insert': 'Before the trip'},
    _line('\n', {'header': 1}),
    {'insert': 'Renew the passport'},
    _line('\n', {'list': 'bullet'}),
    {'insert': 'Packing'},
    _line('\n', {'header': 2}),
    {'insert': 'Take tram 28 early'},
    _line('\n', {'blockquote': true}),
    {'insert': 'Book the transfer\n'},
    {'insert': 'Hotel ref HX-4821'},
    _line('\n', {'code-block': true}),
    {'insert': 'Budget'},
    _line('\n', {'header': 1}),
  ],
});

void main() {
  late QuillController controller;

  Future<void> pumpNote(WidgetTester tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(DisplayDensity.standard),
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
    controller = tester
        .widget<QuillEditor>(find.byType(QuillEditor))
        .controller;
  }

  Rect text(WidgetTester tester, String words) =>
      tester.getRect(find.text(words, findRichText: true).first);

  double gap(WidgetTester tester, String above, String below) =>
      text(tester, below).top - text(tester, above).bottom;

  final typography = NoteTypography(
    lineHeight: AnchorTokens.densityDefaultNoteLineHeight,
  );
  final spacing = NoteBlockSpacing(typography);
  final listPadding = typography.listLinePadding;

  testWidgets('between two blocks only the larger of their spaces counts', (
    tester,
  ) async {
    await pumpNote(tester);

    expect(
      gap(tester, 'Five days in Lisbon', 'Before the trip'),
      closeTo(spacing.heading(1).top, 0.01),
    );
    expect(
      gap(tester, 'Before the trip', 'Renew the passport'),
      closeTo(spacing.heading(1).bottom + listPadding, 0.01),
    );
    expect(
      gap(tester, 'Renew the passport', 'Packing'),
      closeTo(listPadding + spacing.heading(2).top, 0.01),
    );
    expect(
      gap(tester, 'Packing', 'Take tram 28 early'),
      closeTo(spacing.quote.top + spacing.quoteInset.top, 0.01),
    );
    expect(
      gap(tester, 'Take tram 28 early', 'Book the transfer'),
      closeTo(spacing.quoteInset.bottom + spacing.quote.bottom, 0.01),
    );
    expect(
      gap(tester, 'Book the transfer', 'Hotel ref HX-4821'),
      closeTo(spacing.code.top + NoteBlockSpacing.codeInset.top, 0.01),
    );
    expect(
      gap(tester, 'Hotel ref HX-4821', 'Budget'),
      closeTo(NoteBlockSpacing.codeInset.bottom + spacing.heading(1).top, 0.01),
    );
  });

  testWidgets('quotes and code keep their padding inside the panel', (
    tester,
  ) async {
    await pumpNote(tester);
    final editor = text(tester, 'Five days in Lisbon');

    expect(
      text(tester, 'Take tram 28 early').left - editor.left,
      closeTo(spacing.quoteInset.left, 0.01),
    );
    expect(
      text(tester, 'Hotel ref HX-4821').left - editor.left,
      closeTo(NoteBlockSpacing.codeInset.left, 0.01),
    );
    expect(find.text('1', findRichText: true), findsNothing);
  });

  testWidgets('the spacing holds while typing', (tester) async {
    await pumpNote(tester);

    controller.replaceText(
      0,
      0,
      'Six or ',
      const TextSelection.collapsed(offset: 7),
    );
    await tester.pump();
    expect(
      gap(tester, 'Six or Five days in Lisbon', 'Before the trip'),
      closeTo(spacing.heading(1).top, 0.01),
    );

    final heading = controller.document.toPlainText().indexOf('Budget');
    controller.formatText(heading, 0, Attribute.h2);
    await tester.pump();
    expect(
      gap(tester, 'Hotel ref HX-4821', 'Budget'),
      closeTo(NoteBlockSpacing.codeInset.bottom + spacing.heading(2).top, 0.01),
    );
  });
}
