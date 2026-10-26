import 'dart:convert';

import 'package:anchor/features/notes/presentation/editor/append_text.dart';
import 'package:flutter_test/flutter_test.dart';

List<Object?> _ops(String? content) =>
    (jsonDecode(content!) as Map<String, Object?>)['ops']! as List<Object?>;

void main() {
  test('text goes on new lines after what the note says', () {
    final content = appendTextContent(
      jsonEncode({
        'ops': [
          {'insert': 'Groceries\n'},
        ],
      }),
      'Milk\nBread',
    );

    expect(_ops(content), [
      {'insert': 'Groceries\nMilk\nBread\n'},
    ]);
  });

  test('an empty note starts with the text', () {
    expect(_ops(appendTextContent(null, 'Milk')), [
      {'insert': 'Milk\n'},
    ]);
    expect(
      _ops(
        appendTextContent(
          jsonEncode({
            'ops': [
              {'insert': '\n'},
            ],
          }),
          'Milk',
        ),
      ),
      [
        {'insert': 'Milk\n'},
      ],
    );
  });

  test('formatting already in the note stays', () {
    final content = appendTextContent(
      jsonEncode({
        'ops': [
          {
            'insert': 'Title',
            'attributes': {'bold': true},
          },
          {'insert': '\n'},
        ],
      }),
      'Milk',
    );

    expect(_ops(content).first, {
      'insert': 'Title',
      'attributes': {'bold': true},
    });
    expect(_ops(content).last, {'insert': '\nMilk\n'});
  });

  test('after a checklist, the text is a plain line, the items stay', () {
    final content = appendTextContent(
      jsonEncode({
        'ops': [
          {'insert': 'Eggs'},
          {
            'insert': '\n',
            'attributes': {'list': 'unchecked'},
          },
        ],
      }),
      'Milk',
    );

    expect(_ops(content), [
      {'insert': 'Eggs'},
      {
        'insert': '\n',
        'attributes': {'list': 'unchecked'},
      },
      {'insert': 'Milk\n'},
    ]);
  });

  test('nothing to add changes nothing', () {
    expect(appendTextContent('{"ops":[{"insert":"Hi\\n"}]}', '  '), isNull);
  });
}
