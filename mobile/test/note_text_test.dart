import 'dart:convert';

import 'package:anchor/features/notes/domain/note_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String content(List<Map<String, Object>> ops) => jsonEncode({'ops': ops});

  test('writes checklists, bullets and numbers as text', () {
    expect(
      noteToPlainText(
        'Trip',
        content([
          {'insert': 'Pack\nSocks'},
          {
            'insert': '\n',
            'attributes': {'list': 'checked'},
          },
          {'insert': 'Hat'},
          {
            'insert': '\n',
            'attributes': {'list': 'unchecked', 'indent': 1},
          },
          {'insert': 'One'},
          {
            'insert': '\n',
            'attributes': {'list': 'ordered'},
          },
          {'insert': 'Two'},
          {
            'insert': '\n',
            'attributes': {'list': 'ordered'},
          },
          {'insert': 'Dot'},
          {
            'insert': '\n',
            'attributes': {'list': 'bullet'},
          },
        ]),
      ),
      'Trip\n\nPack\n☑ Socks\n  ☐ Hat\n1. One\n2. Two\n• Dot',
    );
  });

  test('leaves out an empty title or body', () {
    expect(
      noteToPlainText(
        '',
        content([
          {'insert': 'Hi\n'},
        ]),
      ),
      'Hi',
    );
    expect(noteToPlainText('Only', null), 'Only');
  });
}
