import 'dart:convert';
import 'dart:io';

import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/core/theme/app_typography.dart';
import 'package:anchor/core/theme/display_density.dart';
import 'package:anchor/core/theme/note_typography.dart';
import 'package:anchor/core/theme/tokens/anchor_tokens.dart';
import 'package:anchor/features/notes/presentation/editor/editor_palette.dart';
import 'package:anchor/features/notes/presentation/editor/rich_text_editor.dart';
import 'package:anchor/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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

final _note = jsonEncode({
  'ops': [
    {'insert': 'Oat milk'},
    {
      'insert': '\n',
      'attributes': {'list': 'unchecked'},
    },
    {'insert': 'Ship the sync fix'},
    {
      'insert': '\n',
      'attributes': {'list': 'ordered'},
    },
    {'insert': 'Retry the token'},
    {
      'insert': '\n',
      'attributes': {'list': 'ordered', 'indent': 1},
    },
    {'insert': 'Tidy up'},
    {
      'insert': '\n',
      'attributes': {'list': 'bullet'},
    },
    {'insert': 'Flights land at nine.\n'},
  ],
});

final _english = lookupAppLocalizations(const Locale('en'));

void main() {
  setUpAll(() async {
    Future<ByteData> bytes(String file) async =>
        ByteData.sublistView(File('assets/fonts/$file').readAsBytesSync());
    await (FontLoader(
      AppTypography.sans,
    )..addFont(bytes('DMSans-Variable.ttf'))).load();
    for (final (family, prefix) in [
      (AppTypography.noteSerif, 'Literata'),
      (AppTypography.mono, 'JetBrainsMono'),
    ]) {
      final loader = FontLoader(family);
      for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
        loader.addFont(bytes('$prefix-$weight.ttf'));
      }
      await loader.load();
    }
  });

  for (final font in NoteFont.values) {
    for (final textSize in [NoteTextSize.standard, NoteTextSize.large]) {
      testWidgets(
        '${font.labelIn(_english)} at ${textSize.labelIn(_english)}: markers sit on their '
        'line\'s letters',
        (tester) async {
          final focus = FocusNode();
          addTearDown(focus.dispose);
          final scroll = ScrollController();
          addTearDown(scroll.dispose);
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.light(DisplayDensity.standard, font, textSize),
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

          final typography = NoteTypography(
            font: font,
            textSize: textSize,
            lineHeight: AnchorTokens.densityDefaultNoteLineHeight,
          );
          final size = typography.bodySize;
          RenderParagraph paragraph(Finder finder) =>
              tester.renderObject<RenderParagraph>(finder.first);
          Finder words(String text) => find.descendant(
            of: find.byType(QuillEditor),
            matching: find.text(text, findRichText: true),
          );
          double baselineOf(RenderParagraph text) {
            final box = text
                .getBoxesForSelection(
                  const TextSelection(baseOffset: 0, extentOffset: 1),
                )
                .first;
            final share = font.descent / (font.ascent + font.descent);
            return text
                .localToGlobal(
                  Offset(0, box.bottom - (box.bottom - box.top) * share),
                )
                .dy;
          }

          final oat = paragraph(words('Oat milk'));
          expect(oat.text.style!.fontFamily, font.family);
          expect(oat.text.style!.fontSize, closeTo(size, 0.001));

          double lettersMiddle(RenderParagraph text) =>
              baselineOf(text) - (font.ascent - font.descent) / 2 * size;
          final box = tester.getRect(
            find.byWidgetPredicate(
              (w) => w is AnimatedContainer && w.constraints?.maxWidth == 22,
            ),
          );
          expect(box.center.dy, closeTo(lettersMiddle(oat), 0.5));
          final bullet = tester.getRect(
            find.byWidgetPredicate(
              (w) => w is Container && w.constraints?.maxWidth == 6,
            ),
          );
          expect(
            bullet.center.dy,
            closeTo(lettersMiddle(paragraph(words('Tidy up'))), 0.5),
          );

          final number = tester.widget<Text>(find.text('1.'));
          expect(number.style!.fontFamily, font.family);
          expect(find.text('a.'), findsOneWidget);
          final rise =
              baselineOf(paragraph(words('Ship the sync fix'))) -
              baselineOf(paragraph(find.text('1.')));
          expect(rise / size, inInclusiveRange(0.05, 0.2));
        },
      );
    }
  }
}
