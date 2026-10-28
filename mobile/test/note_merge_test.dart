import 'dart:convert';

import 'package:anchor/features/notes/domain/note.dart';
import 'package:anchor/features/notes/domain/note_merge.dart';
import 'package:flutter_test/flutter_test.dart';

String doc(List<Map<String, dynamic>> ops) => jsonEncode({'ops': ops});

List<dynamic> opsOf(Note note) =>
    (jsonDecode(note.content!) as Map)['ops'] as List;

void main() {
  test('the first note gets the others\' text, each under its title', () {
    final merged = mergeNotes([
      Note(
        id: 'a',
        title: 'Shopping',
        content: doc([
          {'insert': 'Milk\n'},
        ]),
        tagIds: const ['t1'],
      ),
      Note(
        id: 'b',
        title: 'Hardware',
        content: doc([
          {'insert': 'Nails'},
          {
            'insert': '\n',
            'attributes': {'list': 'unchecked'},
          },
        ]),
        tagIds: const ['t1', 't2'],
      ),
      const Note(id: 'c', title: '', content: 'plain text'),
    ]);

    expect(merged.id, 'a');
    expect(merged.title, 'Shopping');
    expect(merged.tagIds, ['t1', 't2']);
    expect(opsOf(merged), [
      {'insert': 'Milk\n'},
      {'insert': '\n'},
      {
        'insert': 'Hardware',
        'attributes': {'bold': true},
      },
      {'insert': '\n'},
      {'insert': 'Nails'},
      {
        'insert': '\n',
        'attributes': {'list': 'unchecked'},
      },
      {'insert': '\n'},
      {'insert': 'plain text'},
      {'insert': '\n'},
    ]);
  });

  test('an untitled first note takes the next title; no blank first line', () {
    final merged = mergeNotes([
      const Note(id: 'a', title: ' '),
      Note(
        id: 'b',
        title: 'Ideas',
        content: doc([
          {'insert': 'One\n'},
        ]),
      ),
    ]);
    expect(merged.title, 'Ideas');
    expect(opsOf(merged).first, {
      'insert': 'Ideas',
      'attributes': {'bold': true},
    });
  });

  test('pictures in the others\' text stay with their notes', () {
    final merged = mergeNotes([
      Note(
        id: 'a',
        title: 'A',
        content: doc([
          {
            'insert': {'note-image': '{"id":"p1"}'},
          },
          {'insert': '\n'},
        ]),
      ),
      Note(
        id: 'b',
        title: 'B',
        content: doc([
          {
            'insert': {'note-image': '{"id":"p2"}'},
          },
          {'insert': 'Text\n'},
        ]),
      ),
    ]);
    final text = jsonEncode(opsOf(merged));
    expect(text, contains('p1'));
    expect(text, isNot(contains('p2')));
    expect(text, contains('Text'));
  });
}
