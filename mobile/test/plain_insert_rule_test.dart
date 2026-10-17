import 'package:anchor/features/notes/presentation/editor/plain_insert_rule.dart';
import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';

Delta typeInto(
  List<Map<String, dynamic>> ops,
  int at,
  List<String> typed, {
  required bool isPlain,
  int replacing = 0,
}) {
  final document = Document.fromJson(ops)
    ..setCustomRules(isPlain ? const [PlainInsertRule()] : const []);
  var offset = at;
  for (final (index, text) in typed.indexed) {
    document.replace(offset, index == 0 ? replacing : 0, text);
    offset += text.length;
  }
  return document.toDelta();
}

const _bold = {'bold': true};
const _italic = {'italic': true};
const _code = {'code': true};
const _link = {'link': 'https://example.com'};

void main() {
  tearDown(() => Document().setCustomRules(const []));

  final cases = <String, (List<Map<String, dynamic>>, int, List<String>, int)>{
    'inside bold words': (
      [
        {'insert': 'bold', 'attributes': _bold},
        {'insert': '\n'},
      ],
      2,
      ['x', 'y', ' '],
      0,
    ),
    'at the end of bold words': (
      [
        {'insert': 'bold', 'attributes': _bold},
        {'insert': ' plain\n'},
      ],
      4,
      ['e', 'r'],
      0,
    ),
    'inside italic words': (
      [
        {'insert': 'soft', 'attributes': _italic},
        {'insert': '\n'},
      ],
      1,
      ['a'],
      0,
    ),
    'inside a link': (
      [
        {'insert': 'site', 'attributes': _link},
        {'insert': '\n'},
      ],
      2,
      ['x'],
      0,
    ),
    'right after a link': (
      [
        {'insert': 'site', 'attributes': _link},
        {'insert': ' end\n'},
      ],
      4,
      ['s', ' '],
      0,
    ),
    'inside inline code': (
      [
        {'insert': 'a()', 'attributes': _code},
        {'insert': '\n'},
      ],
      2,
      ['b'],
      0,
    ),
    'at the start of a line': (
      [
        {'insert': 'one\n'},
        {'insert': 'two', 'attributes': _bold},
        {'insert': '\n'},
      ],
      4,
      ['a', ' '],
      0,
    ),
    'at the end of a heading, then Enter': (
      [
        {'insert': 'Plan'},
        {
          'insert': '\n',
          'attributes': {'header': 1},
        },
      ],
      4,
      ['s', '\n', 'x'],
      0,
    ),
    'Enter in the middle of a heading': (
      [
        {'insert': 'Plan'},
        {
          'insert': '\n',
          'attributes': {'header': 2},
        },
      ],
      2,
      ['\n'],
      0,
    ),
    'Enter on a bullet': (
      [
        {'insert': 'milk'},
        {
          'insert': '\n',
          'attributes': {'list': 'bullet'},
        },
      ],
      4,
      ['\n', 'e', 'g', 'g', 's'],
      0,
    ),
    'Enter on an empty bullet leaves the list': (
      [
        {'insert': 'milk'},
        {
          'insert': '\n\n',
          'attributes': {'list': 'bullet'},
        },
      ],
      5,
      ['\n'],
      0,
    ),
    'Enter on a checked item': (
      [
        {'insert': 'done'},
        {
          'insert': '\n',
          'attributes': {'list': 'checked'},
        },
      ],
      4,
      ['\n', 'n'],
      0,
    ),
    'Enter on an indented checklist item': (
      [
        {'insert': 'top'},
        {
          'insert': '\n',
          'attributes': {'list': 'unchecked'},
        },
        {'insert': 'sub'},
        {
          'insert': '\n',
          'attributes': {'list': 'unchecked', 'indent': 1},
        },
      ],
      7,
      ['\n', 'x'],
      0,
    ),
    'typing in a code block, then Enter': (
      [
        {'insert': 'let a'},
        {
          'insert': '\n',
          'attributes': {'code-block': true},
        },
      ],
      5,
      [' ', '=', '\n', 'b'],
      0,
    ),
    'Enter in a quote': (
      [
        {'insert': 'said'},
        {
          'insert': '\n',
          'attributes': {'blockquote': true},
        },
      ],
      4,
      ['\n', 'x'],
      0,
    ),
    'lines pasted into a list': (
      [
        {'insert': 'milk'},
        {
          'insert': '\n',
          'attributes': {'list': 'bullet'},
        },
      ],
      4,
      ['\neggs\nbread'],
      0,
    ),
    'lines pasted into a heading': (
      [
        {'insert': 'Plan'},
        {
          'insert': '\n',
          'attributes': {'header': 1},
        },
      ],
      2,
      ['a\nb'],
      0,
    ),
    'a word the keyboard corrects': (
      [
        {'insert': 'teh', 'attributes': _bold},
        {'insert': '\n'},
      ],
      1,
      ['he '],
      2,
    ),
  };

  group('typing keeps every style the way Quill does', () {
    for (final MapEntry(key: name, value: (ops, at, typed, replacing))
        in cases.entries) {
      test(name, () {
        expect(
          typeInto(ops, at, typed, isPlain: true, replacing: replacing),
          typeInto(ops, at, typed, isPlain: false, replacing: replacing),
        );
      });
    }
  });

  group('never links as you type', () {
    bool hasLink(Delta delta) =>
        delta.toList().any((op) => op.attributes?['link'] != null);

    test('an address typed letter by letter, then a space', () {
      final typed = 'see https://example.com/a. '.split('');
      final ops = [
        {'insert': '\n'},
      ];

      expect(hasLink(typeInto(ops, 0, typed, isPlain: false)), isTrue);
      final plain = typeInto(ops, 0, typed, isPlain: true);
      expect(hasLink(plain), isFalse);
      expect(plain.toList().single.data, 'see https://example.com/a. \n');
    });

    test('an address inside pasted words', () {
      final ops = [
        {'insert': '\n'},
      ];
      const pasted = ['go to http://example.com now'];

      expect(hasLink(typeInto(ops, 0, pasted, isPlain: false)), isTrue);
      expect(hasLink(typeInto(ops, 0, pasted, isPlain: true)), isFalse);
    });

    test('an address on pasted lines', () {
      final ops = [
        {'insert': 'a'},
        {
          'insert': '\n',
          'attributes': {'list': 'bullet'},
        },
      ];

      final plain = typeInto(ops, 1, ['\nhttp://example.com'], isPlain: true);

      expect(hasLink(plain), isFalse);
      expect(
        plain.toList().map((op) => op.data).join(),
        'a\nhttp://example.com\n',
      );
    });
  });

  test('leaves embeds to Quill', () {
    expect(
      const PlainInsertRule().apply(
        Document(),
        0,
        data: const BlockEmbed('image', 'x.png').toJson(),
      ),
      isNull,
    );
  });
}
