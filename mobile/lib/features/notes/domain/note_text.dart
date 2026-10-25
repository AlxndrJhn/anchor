import 'note_blocks.dart';

/// A note as plain text for other apps, as Google Keep sends it: the title,
/// a blank line, then the text with ☐/☑ for checklist items and • for
/// bullets, indented with two spaces per level. Matches the web app's.
/// Text that isn't a delta goes as it is.
String noteToPlainText(String title, String? content) {
  final lines = <({String text, String? list, int indent})>[];
  var current = StringBuffer();
  void addLine(Map? attributes) {
    final indent = attributes?['indent'];
    lines.add((
      text: current.toString(),
      list: attributes?['list'] as String?,
      indent: indent is int ? indent : 0,
    ));
    current = StringBuffer();
  }

  for (final op in decodeNoteOps(content).whereType<Map>()) {
    final insert = op['insert'];
    if (insert is! String) continue;
    final parts = insert.split('\n');
    for (var i = 0; i < parts.length; i++) {
      current.write(parts[i]);
      if (i < parts.length - 1) addLine(op['attributes'] as Map?);
    }
  }
  if (current.isNotEmpty) addLine(null);

  final out = <String>[];
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final pad = '  ' * line.indent;
    switch (line.list) {
      case 'checked':
        out.add('$pad☑ ${line.text}');
      case 'unchecked':
        out.add('$pad☐ ${line.text}');
      case 'bullet':
        out.add('$pad• ${line.text}');
      case 'ordered':
        var number = 1;
        for (var j = i - 1; j >= 0; j--) {
          if (lines[j].list != 'ordered') break;
          if (lines[j].indent == line.indent) number++;
        }
        out.add('$pad$number. ${line.text}');
      default:
        out.add(line.text);
    }
  }
  final body = out.join('\n').trim();
  final heading = title.trim();
  return [heading, body].where((part) => part.isNotEmpty).join('\n\n');
}
