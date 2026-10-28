import 'dart:convert';

import 'inline_image.dart';
import 'note.dart';

/// [notes] made into one: the first keeps its place and gets the others'
/// text after its own, each under its title in bold, and all their tags.
///
/// Pictures placed in the others' text are left out: a picture belongs to
/// its note, and those notes stay in the trash with theirs.
Note mergeNotes(List<Note> notes) {
  assert(notes.length >= 2, 'Merging needs two notes');
  final first = notes.first;
  final ops = <Map<String, dynamic>>[..._ops(first.content)];
  for (final note in notes.skip(1)) {
    // A blank line between the notes.
    ops.add({'insert': '\n'});
    if (note.hasTitle) {
      ops
        ..add({
          'insert': note.title.trim(),
          'attributes': {'bold': true},
        })
        ..add({'insert': '\n'});
    }
    ops.addAll(_ops(note.content, dropPictures: true));
  }
  final title = first.hasTitle
      ? first.title
      : notes.map((n) => n.title).firstWhere(hasTitleText, orElse: () => '');
  return first.copyWith(
    title: title,
    content: jsonEncode({'ops': _withoutEmptyStart(ops)}),
    tagIds: {for (final note in notes) ...note.tagIds}.toList(),
  );
}

/// A note's Delta ops, ending in a line break; plain text becomes one op.
List<Map<String, dynamic>> _ops(String? content, {bool dropPictures = false}) {
  if (content == null || content.trim().isEmpty) return const [];
  List<Map<String, dynamic>> ops;
  try {
    final json = jsonDecode(content);
    ops = json is Map && json['ops'] is List
        ? [
            for (final op in json['ops'] as List)
              if (op is Map) Map<String, dynamic>.from(op),
          ]
        : [
            {'insert': content},
          ];
  } catch (_) {
    ops = [
      {'insert': content},
    ];
  }
  if (dropPictures) {
    ops = [
      for (final op in ops)
        if (!(op['insert'] is Map &&
            (op['insert'] as Map).containsKey(InlineImage.embedType)))
          op,
    ];
  }
  // An empty note is a lone line break: nothing to add.
  if (ops.length == 1 && ops.first['insert'] == '\n') return const [];
  final last = ops.isEmpty ? null : ops.last['insert'];
  if (last is! String || !last.endsWith('\n')) ops.add({'insert': '\n'});
  return ops;
}

/// Drops the blank line added before the first merged note when the first
/// note had no text of its own.
List<Map<String, dynamic>> _withoutEmptyStart(List<Map<String, dynamic>> ops) {
  if (ops.isNotEmpty && ops.first['insert'] == '\n' && ops.first.length == 1) {
    return ops.sublist(1);
  }
  return ops;
}
