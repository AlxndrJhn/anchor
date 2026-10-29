import 'dart:convert';

import '../../../core/links/link_utils.dart';

final _run = RegExp(r'\S+');

/// Every address is linked as typing links it; null when both are empty.
String? shareNoteContent(String text, {String? link}) {
  final body = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trimRight();
  if (body.isEmpty && link == null) return null;

  final ops = <Map<String, Object?>>[];
  void insert(String text, [String? url]) {
    if (text.isEmpty) return;
    final attributes = url == null ? null : {'link': url};
    final last = ops.lastOrNull;
    if (attributes == null && last != null && last['attributes'] == null) {
      last['insert'] = '${last['insert']}$text';
    } else {
      ops.add({'insert': text, 'attributes': ?attributes});
    }
  }

  var at = 0;
  for (final match in _run.allMatches(body)) {
    final word = wordIn(match[0]!);
    final url = word == null ? null : linkForTypedAddress(word.text);
    if (word == null || url == null) continue;
    final start = match.start + word.start;
    insert(body.substring(at, start));
    insert(word.text, url);
    at = start + word.text.length;
  }
  insert(body.substring(at));
  if (link != null) {
    if (body.isNotEmpty) insert('\n');
    insert(link, normalizeUrl(link));
  }
  insert('\n');
  return jsonEncode({'ops': ops});
}
