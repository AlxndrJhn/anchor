import 'package:anchor/features/notes/presentation/editor/editor_format.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  QuillController controllerOf(List<Map<String, Object>> ops) =>
      QuillController(
        document: Document.fromJson(ops),
        selection: const TextSelection.collapsed(offset: 0),
      );

  test('text grabbed from a picture goes after a checklist as plain lines', () {
    final controller = controllerOf([
      {'insert': 'Milk'},
      {
        'insert': '\n',
        'attributes': {'list': 'unchecked'},
      },
    ]);

    controller.appendPlainLines('Harbor Road 12\nOpen 9-5\n');

    expect(controller.document.toDelta().toJson(), [
      {'insert': 'Milk'},
      {
        'insert': '\n',
        'attributes': {'list': 'unchecked'},
      },
      {'insert': 'Harbor Road 12\nOpen 9-5\n'},
    ]);
    expect(controller.selection.baseOffset, controller.document.length - 1);
  });

  test('an empty note takes the text on its blank line', () {
    final controller = controllerOf([
      {'insert': '\n'},
    ]);

    controller.appendPlainLines('Receipt');

    expect(controller.document.toPlainText(), 'Receipt\n');
  });

  test('blank text adds nothing', () {
    final controller = controllerOf([
      {'insert': 'Note\n'},
    ]);

    controller.appendPlainLines('  \n ');

    expect(controller.document.toPlainText(), 'Note\n');
  });
}
