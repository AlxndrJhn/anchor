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

  test('nothing ticked gives no change', () {
    final lines = parseDocumentLines(docFrom([('a', 'unchecked')]));
    expect(buildUncheckAllDelta(lines), isNull);
    expect(buildRemoveCheckedDelta(lines), isNull);
  });
}
