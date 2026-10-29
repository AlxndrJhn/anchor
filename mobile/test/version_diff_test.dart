import 'dart:convert';

import 'package:anchor/features/notes/domain/note_blocks.dart';
import 'package:anchor/features/notes/domain/version_diff.dart';
import 'package:flutter_test/flutter_test.dart';

String doc(List<Object> lines) {
  final ops = <Map<String, dynamic>>[];
  for (final line in lines) {
    final (text, attributes) = switch (line) {
      (String t, Map<String, dynamic> a) => (t, a),
      _ => (line as String, null),
    };
    if (text.isNotEmpty) ops.add({'insert': text});
    ops.add({'insert': '\n', 'attributes': ?attributes});
  }
  return jsonEncode({'ops': ops});
}

String delta(List<Map<String, dynamic>> ops) => jsonEncode({'ops': ops});

List<(ChangeKind, String)> marks(String? before, String? after) => [
  for (final line in diffVersions(before, after).lines)
    (line.kind, line.block.text),
];

List<(String, WordKind)> words(List<WordPart> parts) => [
  for (final part in parts) (part.text, part.kind),
];

List<VersionLine> linesOf(List<ChangeKind> kinds) => [
  for (final kind in kinds)
    VersionLine(kind, const NoteBlock(type: BlockType.paragraph)),
];

List<Object> folded(List<VersionLine> lines, [Set<int> open = const {}]) => [
  for (final item in foldLines(lines, open))
    item is FoldedLines ? (item.from, item.to) : item,
];

void main() {
  group('diffWords', () {
    test('keeps what stayed and marks what went and came', () {
      expect(words(diffWords('Fado dinner at 8 pm', 'Fado dinner at 9 pm')), [
        ('Fado dinner at ', WordKind.same),
        ('8', WordKind.removed),
        ('9', WordKind.added),
        (' pm', WordKind.same),
      ]);
    });

    test('handles a line that was emptied or filled', () {
      expect(words(diffWords('', 'new')), [('new', WordKind.added)]);
      expect(words(diffWords('old', '')), [('old', WordKind.removed)]);
    });
  });

  group('diffVersions', () {
    test('marks nothing when the text is the same', () {
      final diff = diffVersions(doc(['milk', 'eggs']), doc(['milk', 'eggs']));

      expect([diff.added, diff.removed, diff.changed], [0, 0, 0]);
      expect(diff.isUnchanged, isTrue);
    });

    test('shows a small edit as one changed line', () {
      final diff = diffVersions(
        doc(['Check in after 3 pm', 'Fado dinner at 8 pm']),
        doc(['Check in after 3 pm', 'Fado dinner at 9 pm']),
      );

      expect(diff.changed, 1);
      expect(diff.lines[1].kind, ChangeKind.changed);
      expect(diff.isUnchanged, isFalse);
    });

    test('keeps lines that have little in common as removed and added', () {
      expect(
        marks(
          doc(['milk', 'Buy a new bike helmet']),
          doc(['milk', 'Call the dentist tomorrow']),
        ),
        [
          (ChangeKind.same, 'milk'),
          (ChangeKind.removed, 'Buy a new bike helmet'),
          (ChangeKind.added, 'Call the dentist tomorrow'),
        ],
      );
    });

    test('shows ticking an item as a change to that line', () {
      final diff = diffVersions(
        doc([
          ('Book the flights', <String, dynamic>{'list': 'unchecked'}),
        ]),
        doc([
          ('Book the flights', <String, dynamic>{'list': 'checked'}),
        ]),
      );

      expect(diff.lines, hasLength(1));
      expect(diff.lines.single.kind, ChangeKind.changed);
      expect(words(diff.lines.single.words), [
        ('Book the flights', WordKind.same),
      ]);
    });

    test('shows a line turned into a heading as a change', () {
      final diff = diffVersions(
        doc(['Plans']),
        doc([
          ('Plans', <String, dynamic>{'header': 2}),
        ]),
      );

      expect(diff.lines, hasLength(1));
      expect(diff.changed, 1);
    });

    test('marks lines the next version added and removed', () {
      expect(marks(doc(['a', 'b']), doc(['a', 'c', 'b'])), [
        (ChangeKind.same, 'a'),
        (ChangeKind.added, 'c'),
        (ChangeKind.same, 'b'),
      ]);
      expect(marks(doc(['a', 'b', 'c']), doc(['a', 'c'])), [
        (ChangeKind.same, 'a'),
        (ChangeKind.removed, 'b'),
        (ChangeKind.same, 'c'),
      ]);
    });

    test('leaves out empty lines', () {
      expect(marks(doc(['a', '', '   ', 'b']), doc(['a', 'b'])), [
        (ChangeKind.same, 'a'),
        (ChangeKind.same, 'b'),
      ]);
    });

    test('reads a bolded word as the same line', () {
      final before = delta([
        {'insert': 'buy milk\n'},
      ]);
      final after = delta([
        {'insert': 'buy '},
        {
          'insert': 'milk',
          'attributes': {'bold': true},
        },
        {'insert': '\n'},
      ]);

      final diff = diffVersions(before, after);

      expect(diff.isUnchanged, isTrue);
      expect(marks(before, after), [(ChangeKind.same, 'buy milk')]);
    });

    test('carries a line formatting through for drawing', () {
      final content = delta([
        {'insert': 'buy '},
        {
          'insert': 'milk',
          'attributes': {'bold': true},
        },
        {
          'insert': '\n',
          'attributes': {'list': 'bullet', 'indent': 1},
        },
      ]);

      final block = diffVersions(content, content).lines.single.block;

      expect(block.type, BlockType.bullet);
      expect(block.level, 1);
      expect(block.runs.map((run) => run.text), ['buy ', 'milk']);
      expect(block.runs.first.bold, isFalse);
      expect(block.runs.last.bold, isTrue);
    });

    test('reads a quote and a code block off the line', () {
      final content = doc([
        ('stay calm', <String, dynamic>{'blockquote': true}),
        ('print(1)', <String, dynamic>{'code-block': true}),
      ]);

      final lines = diffVersions(content, content).lines;

      expect(lines[0].block.type, BlockType.quote);
      expect(lines[1].block.type, BlockType.code);
    });

    test('reads content that is not JSON as plain lines', () {
      expect(marks('not json\nsecond line', null), [
        (ChangeKind.removed, 'not json'),
        (ChangeKind.removed, 'second line'),
      ]);
    });

    test('reads two empty notes as unchanged', () {
      final diff = diffVersions(null, null);

      expect(diff.lines, isEmpty);
      expect(diff.isUnchanged, isTrue);
    });

    test('reads an empty note against a written one as all added', () {
      final after = doc(['milk', 'bread']);

      expect(marks(null, after), [
        (ChangeKind.added, 'milk'),
        (ChangeKind.added, 'bread'),
      ]);
      expect(diffVersions(null, after).removed, 0);
    });
  });

  group('foldLines', () {
    const same = ChangeKind.same;
    const added = ChangeKind.added;

    test('keeps two lines around a change and folds three or more', () {
      final lines = linesOf([
        same,
        same,
        same,
        same,
        same,
        added,
        same,
        same,
        same,
        same,
        same,
        same,
      ]);

      expect(folded(lines), [(0, 3), 3, 4, 5, 6, 7, (8, 12)]);
    });

    test("doesn't fold two lines", () {
      final lines = linesOf([same, same, same, same, added]);

      expect(folded(lines), [0, 1, 2, 3, 4]);
    });

    test('opens a fold that was opened', () {
      final lines = linesOf([same, same, same, same, same, added]);

      expect(folded(lines, {0, 1, 2}), [0, 1, 2, 3, 4, 5]);
    });
  });
}
