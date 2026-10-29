import 'dart:io';
import 'dart:typed_data';

import 'package:anchor/core/theme/anchor_density.dart';
import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/core/theme/app_typography.dart';
import 'package:anchor/core/theme/context_extensions.dart';
import 'package:anchor/core/theme/display_density.dart';
import 'package:anchor/core/theme/note_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

({double ascent, double descent, int weight, bool isItalic}) _metricsOf(
  String file,
) {
  final data = File('assets/fonts/$file').readAsBytesSync();
  final view = ByteData.sublistView(data);
  final offsets = <String, int>{};
  for (var i = 0; i < view.getUint16(4); i++) {
    final record = 12 + 16 * i;
    offsets[String.fromCharCodes(data.sublist(record, record + 4))] = view
        .getUint32(record + 8);
  }
  final unitsPerEm = view.getUint16(offsets['head']! + 18);
  final hhea = offsets['hhea']!;
  final os2 = offsets['OS/2']!;
  return (
    ascent: view.getInt16(hhea + 4) / unitsPerEm,
    descent: -view.getInt16(hhea + 6) / unitsPerEm,
    weight: view.getUint16(os2 + 4),
    isItalic: view.getUint16(os2 + 62) & 1 == 1,
  );
}

void main() {
  group('sizes', () {
    test(
      'the text size scales the editor, and Mono is set a tenth smaller',
      () {
        for (final (font, textSize, scale) in [
          (NoteFont.sans, NoteTextSize.small, 0.88),
          (NoteFont.sans, NoteTextSize.standard, 1.0),
          (NoteFont.serif, NoteTextSize.large, 1.12),
          (NoteFont.mono, NoteTextSize.standard, 0.9),
          (NoteFont.mono, NoteTextSize.large, 0.9 * 1.12),
        ]) {
          final typography = NoteTypography(
            font: font,
            textSize: textSize,
            lineHeight: 1.7,
          );
          expect(typography.body.fontSize, closeTo(16.5 * scale, 0.001));
          expect(typography.title.fontSize, closeTo(27 * scale, 0.001));
          expect(typography.previewTitle.fontSize, closeTo(20 * scale, 0.001));
          expect(
            typography.heading(1).fontSize,
            closeTo(AppTypography.noteHeading(1).fontSize! * scale, 0.001),
          );
          for (final style in [
            typography.body,
            typography.title,
            typography.heading(2),
            typography.listNumber,
            typography.previewTitle,
          ]) {
            expect(style.fontFamily, font.family);
          }
        }
      },
    );

    test('cards and versions take the face but keep their sizes', () {
      final typography = NoteTypography(
        font: NoteFont.mono,
        textSize: NoteTextSize.large,
        lineHeight: 1.55,
      );
      expect(typography.cardTitle.fontFamily, AppTypography.mono);
      expect(typography.cardTitle.fontSize, AppTypography.cardTitle.fontSize);
      expect(typography.cardBody.fontSize, AppTypography.cardBody.fontSize);
      expect(typography.versionTitle.fontSize, 27);
      expect(typography.versionBody.fontSize, 16.5);
      expect(typography.versionBody.height, 1.55);
      expect(typography.versionHeading(3).fontFamily, AppTypography.mono);
    });

    test('the title keeps its fixed tracking at every size', () {
      final large = NoteTypography(
        font: NoteFont.serif,
        textSize: NoteTextSize.large,
        lineHeight: 1.7,
      );
      expect(large.title.letterSpacing, AppTypography.noteTitle.letterSpacing);
      expect(large.title.height, AppTypography.noteTitle.height);
      expect(large.title.fontWeight, FontWeight.w700);
    });
  });

  group('the theme', () {
    test('carries the face, the size and the density\'s line height', () {
      for (final density in DisplayDensity.values) {
        final typography = AppTheme.dark(
          density,
          NoteFont.serif,
          NoteTextSize.small,
        ).extension<NoteTypography>()!;
        expect(typography.font, NoteFont.serif);
        expect(typography.textSize, NoteTextSize.small);
        expect(typography.lineHeight, AnchorDensity.of(density).noteLineHeight);
        expect(typography.body.height, typography.lineHeight);
      }
    });

    test('is built once for each set of choices', () {
      expect(
        identical(
          AppTheme.light(DisplayDensity.standard, NoteFont.mono),
          AppTheme.light(DisplayDensity.standard, NoteFont.mono),
        ),
        isTrue,
      );
      expect(
        identical(
          AppTheme.light(DisplayDensity.standard, NoteFont.mono),
          AppTheme.light(
            DisplayDensity.standard,
            NoteFont.mono,
            NoteTextSize.large,
          ),
        ),
        isFalse,
      );
    });

    testWidgets('falls back to Sans at Default with the density\'s lines', (
      tester,
    ) async {
      late NoteTypography typography;
      await tester.pumpWidget(
        Theme(
          data: ThemeData(extensions: [AnchorDensity.compact]),
          child: Builder(
            builder: (context) {
              typography = context.noteTypography;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(typography.font, NoteFont.sans);
      expect(typography.textSize, NoteTextSize.standard);
      expect(typography.lineHeight, AnchorDensity.compact.noteLineHeight);
    });
  });

  group('the bundled fonts', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();

    for (final (family, prefix) in [
      (AppTypography.noteSerif, 'Literata'),
      (AppTypography.mono, 'JetBrainsMono'),
    ]) {
      test('$family has every weight and italic notes ask for', () {
        final start = pubspec.indexOf('- family: $family');
        final next = pubspec.indexOf('- family:', start + 1);
        final block = pubspec.substring(start, next < 0 ? null : next);
        for (final (file, weight, isItalic) in [
          ('Regular', 400, false),
          ('Italic', 400, true),
          ('Medium', 500, false),
          ('SemiBold', 600, false),
          ('Bold', 700, false),
          ('BoldItalic', 700, true),
        ]) {
          final asset = 'assets/fonts/$prefix-$file.ttf';
          expect(block, contains(asset));
          final metrics = _metricsOf('$prefix-$file.ttf');
          expect(metrics.weight, weight, reason: asset);
          expect(metrics.isItalic, isItalic, reason: asset);
        }
        expect(File('assets/fonts/OFL-$prefix.txt').existsSync(), isTrue);
      });
    }

    test('each face\'s ascent and descent are its font\'s own', () {
      for (final (font, file) in [
        (NoteFont.sans, 'DMSans-Variable.ttf'),
        (NoteFont.serif, 'Literata-Regular.ttf'),
        (NoteFont.mono, 'JetBrainsMono-Regular.ttf'),
      ]) {
        final metrics = _metricsOf(file);
        expect(font.ascent, metrics.ascent, reason: file);
        expect(font.descent, metrics.descent, reason: file);
      }
    });
  });
}
