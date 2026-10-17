import 'package:anchor/features/notes/presentation/editor/editor_format.dart';
import 'package:anchor/features/notes/presentation/editor/line_kind.dart';
import 'package:anchor/features/notes/presentation/editor/markdown_shortcuts.dart';
import 'package:anchor/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';

QuillController controllerAt(int offset, List<Map<String, dynamic>> ops) {
  final controller = QuillController(
    document: Document.fromJson(ops),
    selection: TextSelection.collapsed(offset: offset),
  );
  addTearDown(controller.dispose);
  return controller;
}

QuillController typed(String text, {Map<String, Object>? line}) =>
    controllerAt(text.length, [
      {'insert': text},
      {'insert': '\n', 'attributes': ?line},
    ]);

final _english = lookupAppLocalizations(const Locale('en'));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('applyMarkdownShortcut', () {
    const kinds = {
      '- ': LineKind.bullet,
      '* ': LineKind.bullet,
      '+ ': LineKind.bullet,
      '1. ': LineKind.numbered,
      '2. ': LineKind.numbered,
      '12) ': LineKind.numbered,
      '[] ': LineKind.checklist,
      '[ ] ': LineKind.checklist,
      '[x] ': LineKind.checklist,
      '# ': LineKind.h1,
      '## ': LineKind.h2,
      '### ': LineKind.h3,
      '> ': LineKind.quote,
      '``` ': LineKind.code,
      '  - ': LineKind.bullet,
      '-\u00a0': LineKind.bullet,
    };

    for (final MapEntry(key: shortcut, value: kind) in kinds.entries) {
      test('"$shortcut" starts a ${kind.name} line', () {
        final controller = typed(shortcut);

        expect(controller.applyMarkdownShortcut(), isTrue);

        expect(controller.lineKind, kind);
        expect(controller.document.toPlainText(), '\n');
        expect(controller.selection, const TextSelection.collapsed(offset: 0));
      });
    }

    test('"[x] " starts a ticked item, "[ ] " an open one', () {
      final ticked = typed('[x] ');
      final open = typed('[ ] ');

      ticked.applyMarkdownShortcut();
      open.applyMarkdownShortcut();

      expect(ticked.document.toDelta().last.attributes, {'list': 'checked'});
      expect(open.document.toDelta().last.attributes, {'list': 'unchecked'});
    });

    test('keeps the words after the caret on the new line', () {
      final controller = controllerAt(2, [
        {'insert': '- milk\n'},
      ]);

      expect(controller.applyMarkdownShortcut(), isTrue);

      expect(controller.document.toPlainText(), 'milk\n');
      expect(controller.lineKind, LineKind.bullet);
      expect(controller.selection, const TextSelection.collapsed(offset: 0));
    });

    test('starts the caret line, not the line above', () {
      final controller = controllerAt(8, [
        {'insert': 'first\n- \n'},
      ]);

      expect(controller.applyMarkdownShortcut(), isTrue);

      expect(controller.document.toPlainText(), 'first\n\n');
      expect(controller.lineKind, LineKind.bullet);
      controller.updateSelection(
        const TextSelection.collapsed(offset: 0),
        ChangeSource.local,
      );
      expect(controller.lineKind, LineKind.text);
    });

    test('changes a heading or a list line to the kind typed', () {
      final heading = typed('# ', line: {'header': 3});
      final item = typed('1. ', line: {'list': 'unchecked', 'indent': 1});

      expect(heading.applyMarkdownShortcut(), isTrue);
      expect(item.applyMarkdownShortcut(), isTrue);

      expect(heading.lineKind, LineKind.h1);
      expect(item.lineKind, LineKind.numbered);
      expect(item.indentLevel, 1);
    });

    test('leaves code and quotes alone', () {
      for (final line in [
        {'code-block': true},
        {'blockquote': true},
      ]) {
        final controller = typed('- ', line: line);

        expect(controller.applyMarkdownShortcut(), isFalse, reason: '$line');
        expect(controller.document.toPlainText(), '- \n');
      }
    });

    test('only answers a starter that is all that is before the caret', () {
      for (final text in [
        'a- ',
        '- a ',
        '-- ',
        '#### ',
        '[xx] ',
        '1.2 ',
        '-',
      ]) {
        final controller = typed(text);

        expect(controller.applyMarkdownShortcut(), isFalse, reason: text);
        expect(controller.document.toPlainText(), '$text\n');
      }
    });

    test('needs a caret, not a selection', () {
      final controller = typed('- ')
        ..updateSelection(
          const TextSelection(baseOffset: 0, extentOffset: 2),
          ChangeSource.local,
        );

      expect(controller.applyMarkdownShortcut(), isFalse);
    });
  });

  group('textBeforeCaret', () {
    test('reads only the caret line', () {
      final controller = controllerAt(9, [
        {'insert': 'first\nsecond\n'},
      ]);

      expect(textBeforeCaret(controller), 'sec');
    });

    test('is empty at the start of a line', () {
      expect(
        textBeforeCaret(
          controllerAt(6, [
            {'insert': 'first\nsecond\n'},
          ]),
        ),
        '',
      );
    });
  });

  group('slashQueryAt', () {
    test('reads what follows a slash that starts a word on the caret line', () {
      final cases = <String, (QuillController, int, String)>{
        'at the start of a line': (
          controllerAt(11, [
            {'insert': 'note\n/check\n'},
          ]),
          5,
          'check',
        ),
        'alone': (
          controllerAt(1, [
            {'insert': '/\n'},
          ]),
          0,
          '',
        ),
        'after a word': (
          controllerAt(7, [
            {'insert': 'buy /ch milk\n'},
          ]),
          4,
          'ch',
        ),
        'with words that match': (
          controllerAt(10, [
            {'insert': '/bullet li\n'},
          ]),
          0,
          'bullet li',
        ),
      };
      for (final MapEntry(key: reason, value: (controller, slashOffset, query))
          in cases.entries) {
        expect(
          slashQueryAt(controller, slashOffset: slashOffset, l10n: _english),
          query,
          reason: reason,
        );
      }
    });

    test('answers on any kind of line but code', () {
      const kinds = <String, Map<String, Object>>{
        'checklist': {'list': 'unchecked'},
        'bullet': {'list': 'bullet'},
        'numbered': {'list': 'ordered'},
        'heading': {'header': 2},
        'quote': {'blockquote': true},
      };
      for (final MapEntry(key: kind, value: attributes) in kinds.entries) {
        final controller = controllerAt(7, [
          {'insert': 'eggs /x'},
          {'insert': '\n', 'attributes': attributes},
        ]);
        expect(
          slashQueryAt(controller, slashOffset: 5, l10n: _english),
          'x',
          reason: kind,
        );
      }
      final code = controllerAt(7, [
        {'insert': 'eggs /x'},
        {
          'insert': '\n',
          'attributes': {'code-block': true},
        },
      ]);
      expect(slashQueryAt(code, slashOffset: 5, l10n: _english), isNull);
    });

    test('has nothing to answer away from a fresh slash', () {
      final cases = <String, (QuillController, int)>{
        'inside a word': (
          controllerAt(5, [
            {'insert': 'and/or\n'},
          ]),
          3,
        ),
        'another slash': (
          controllerAt(11, [
            {'insert': '/a\n/check\n'},
          ]),
          0,
        ),
        'a slash after it': (
          controllerAt(5, [
            {'insert': '/usr/\n'},
          ]),
          0,
        ),
        'a space right after it': (
          controllerAt(4, [
            {'insert': 'a / \n'},
          ]),
          2,
        ),
        'words that match nothing after a space': (
          controllerAt(6, [
            {'insert': '/zz yy\n'},
          ]),
          0,
        ),
        'over a selection': (
          controllerAt(0, [
            {'insert': '/x\n'},
          ])..updateSelection(
            const TextSelection(baseOffset: 0, extentOffset: 2),
            ChangeSource.local,
          ),
          0,
        ),
      };
      for (final MapEntry(key: reason, value: (controller, slashOffset))
          in cases.entries) {
        expect(
          slashQueryAt(controller, slashOffset: slashOffset, l10n: _english),
          isNull,
          reason: reason,
        );
      }
    });
  });
}
