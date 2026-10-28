import 'package:anchor/core/widgets/editor/date_command.dart';
import 'package:anchor/core/widgets/rich_text_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the date reads like "Oct 28th 2026"', () {
    expect(formatLongDate(DateTime(2026, 10, 28)), 'Oct 28th 2026');
    expect(formatLongDate(DateTime(2026, 1, 1)), 'Jan 1st 2026');
    const days = [1, 2, 3, 4, 11, 12, 13, 21, 22, 23, 30, 31];
    expect(days.map(ordinal), [
      '1st',
      '2nd',
      '3rd',
      '4th',
      '11th',
      '12th',
      '13th',
      '21st',
      '22nd',
      '23rd',
      '30th',
      '31st',
    ]);
  });

  group('a typed /date', () {
    /// [before] typed, then [key] typed after it.
    int? finished(String before, String key) {
      final document = Document()..insert(0, before);
      final change = document.insert(before.length, key);
      return finishedDateCommandAt(document, change);
    }

    test('is found once a space or Enter follows it', () {
      expect(finished('/date', ' '), 0);
      expect(finished('Met on /date', ' '), 7);
      expect(finished('Met on /date', '\n'), 7);
      expect(finished('/Date', ' '), 0);
    });

    test('is left alone otherwise', () {
      expect(finished('/dat', 'e'), isNull);
      expect(finished('/dates', ' '), isNull);
      expect(finished('a/date', ' '), isNull);
      expect(finished('date', ' '), isNull);
    });
  });

  testWidgets('/date and a space become today\'s date', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates:
            FlutterQuillLocalizations.localizationsDelegates,
        home: Scaffold(
          body: RichTextEditor(initialContent: '{"ops":[{"insert":"\\n"}]}'),
        ),
      ),
    );
    final state = tester.state<RichTextEditorState>(
      find.byType(RichTextEditor),
    );
    final controller = state.controller;
    for (final char in 'Due /date '.split('')) {
      final at = controller.selection.baseOffset;
      controller.replaceText(
        at,
        0,
        char,
        TextSelection.collapsed(offset: at + 1),
      );
      await tester.pump();
    }

    final date = formatLongDate(DateTime.now());
    expect(controller.document.toPlainText(), 'Due $date \n');
    expect(controller.selection.baseOffset, 'Due $date '.length);
  });
}
