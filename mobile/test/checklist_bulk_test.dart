import 'dart:convert';

import 'package:anchor/core/widgets/editor/checklist_lines.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';

Document docFrom(List<(String, String?)> lines) {
  final ops = <Map<String, dynamic>>[];
  for (final (text, list) in lines) {
    if (text.isNotEmpty) ops.add({'insert': text});
    ops.add({
      'insert': '\n',
      if (list != null) 'attributes': {'list': list},
    });
  }
  return Document.fromJson(ops);
}

List<(String, String?)> linesOf(Document doc) {
  final text = doc.toPlainText();
  return [
    for (final line in parseDocumentLines(doc))
      (
        text.substring(line.startOffset, line.startOffset + line.length - 1),
        line.listType,
      ),
  ];
}

void main() {
  final shopping = [
    ('Groceries', null),
    ('Milk', 'checked'),
    ('Eggs', 'unchecked'),
    ('Bread', 'checked'),
    ('Done', null),
  ];

  test('unticks every ticked item', () {
    final doc = docFrom(shopping);
    doc.compose(
      buildUncheckAllDelta(parseDocumentLines(doc))!,
      ChangeSource.local,
    );
    expect(linesOf(doc), [
      ('Groceries', null),
      ('Milk', 'unchecked'),
      ('Eggs', 'unchecked'),
      ('Bread', 'unchecked'),
      ('Done', null),
    ]);
  });

  test('deletes every ticked item', () {
    final doc = docFrom(shopping);
    doc.compose(
      buildRemoveCheckedDelta(parseDocumentLines(doc))!,
      ChangeSource.local,
    );
    expect(linesOf(doc), [
      ('Groceries', null),
      ('Eggs', 'unchecked'),
      ('Done', null),
    ]);
  });

  test('a ticked last line leaves an empty plain line', () {
    final doc = docFrom([('Eggs', 'unchecked'), ('Milk', 'checked')]);
    doc.compose(
      buildRemoveCheckedDelta(parseDocumentLines(doc))!,
      ChangeSource.local,
    );
    expect(linesOf(doc), [('Eggs', 'unchecked'), ('', null)]);
  });

  group('toggleChecklistItemContent', () {
    String stored(List<(String, String?)> lines) =>
        jsonEncode({'ops': docFrom(lines).toDelta().toJson()});
    List<(String, String?)> read(String? content) => linesOf(
      Document.fromJson((jsonDecode(content!) as Map)['ops'] as List),
    );
    final list = stored([
      ('Eggs', 'unchecked'),
      ('Milk', 'unchecked'),
      ('Done', 'checked'),
    ]);

    test('ticks an item in place', () {
      expect(read(toggleChecklistItemContent(list, 0, sort: false)), [
        ('Eggs', 'checked'),
        ('Milk', 'unchecked'),
        ('Done', 'checked'),
      ]);
    });

    test('moves a ticked item to the bottom when sorting', () {
      expect(read(toggleChecklistItemContent(list, 0, sort: true)), [
        ('Milk', 'unchecked'),
        ('Done', 'checked'),
        ('Eggs', 'checked'),
      ]);
    });

    test('ignores lines that are not checklist items', () {
      expect(
        toggleChecklistItemContent(stored([('a', null)]), 0, sort: false),
        isNull,
      );
    });
  });

  group('show and hide checkboxes', () {
    test('turns every written line into an unchecked item', () {
      final doc = docFrom([
        ('Groceries', null),
        ('Milk', 'checked'),
        ('', null),
        ('Eggs', 'bullet'),
      ]);
      final lines = parseDocumentLines(doc);
      expect(hasLinesWithoutCheckboxes(lines), isTrue);
      doc.compose(buildShowCheckboxesDelta(lines)!, ChangeSource.local);
      expect(linesOf(doc), [
        ('Groceries', 'unchecked'),
        ('Milk', 'checked'),
        ('', null),
        ('Eggs', 'unchecked'),
      ]);
      expect(allLinesAreChecklist(parseDocumentLines(doc)), isTrue);
      expect(hasLinesWithoutCheckboxes(parseDocumentLines(doc)), isFalse);
    });

    test('hide turns the items back into plain lines', () {
      final doc = docFrom([('Milk', 'checked'), ('Eggs', 'unchecked')]);
      doc.compose(
        buildHideCheckboxesDelta(parseDocumentLines(doc))!,
        ChangeSource.local,
      );
      expect(linesOf(doc), [('Milk', null), ('Eggs', null)]);
    });
  });

  test('nothing ticked gives no change', () {
    final lines = parseDocumentLines(docFrom([('a', 'unchecked')]));
    expect(buildUncheckAllDelta(lines), isNull);
    expect(buildRemoveCheckedDelta(lines), isNull);
  });
}
