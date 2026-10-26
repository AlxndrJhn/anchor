import 'dart:convert';

import 'package:anchor/core/widgets/editor/append_text.dart';
import 'package:flutter_test/flutter_test.dart';

List<Object?> _ops(String content) =>
    (jsonDecode(content) as Map<String, Object?>)['ops']! as List<Object?>;

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
}
