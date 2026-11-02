import 'dart:convert';

import 'anchor_protocol.dart';

/// Characters a header name may have (RFC 9110 tokens).
final RegExp _headerName = RegExp(r"^[!#$%&'*+\-.^_`|~0-9A-Za-z]+$");

/// Characters a header value may have on the wire.
final RegExp _headerValue = RegExp(r'^[\t\x20-\x7E\x80-\xFF]+$');

/// Headers the app sets itself: one typed here would replace it.
const Set<String> _reservedNames = {
  'accept',
  'authorization',
  'connection',
  'content-length',
  'content-type',
  'host',
  'transfer-encoding',
  'user-agent',
};

enum ServerHeaderProblem {
  notNameValue,
  badName,
  badValue,
  reservedName,
  repeatedName,
}

/// What's wrong with one line of the headers, counting from 1.
typedef ServerHeaderError = ({int line, ServerHeaderProblem problem});

/// Extra headers sent with every request to one server, as typed: one
/// `Name: value` per line, the way a proxy's setup page shows them.
/// Blank lines and lines starting with `#` are skipped.
class ServerHeaders {
  const ServerHeaders({required this.server, required this.text});

  /// The address they were saved for. They go to no other.
  final String server;

  final String text;

  /// The headers for [url], none when they were saved for another server.
  Map<String, String> forServer(String? url) =>
      url == server ? parseServerHeaders(text).headers : const {};

  String toJson() => jsonEncode({'server': server, 'text': text});

  static ServerHeaders? fromJson(String? value) {
    if (value == null) return null;
    try {
      final json = jsonDecode(value);
      if (json case {
        'server': final String server,
        'text': final String text,
      }) {
        return ServerHeaders(server: server, text: text);
      }
    } on FormatException {
      // Unreadable: as if none were saved.
    }
    return null;
  }
}

/// The well-formed headers in [text], and the lines that aren't.
({Map<String, String> headers, List<ServerHeaderError> errors})
parseServerHeaders(String text) {
  final headers = <String, String>{};
  final seen = <String>{};
  final errors = <ServerHeaderError>[];
  final lines = const LineSplitter().convert(text);
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final colon = line.indexOf(':');
    final name = colon < 0 ? '' : line.substring(0, colon).trim();
    final value = colon < 0 ? '' : line.substring(colon + 1).trim();
    final lowered = name.toLowerCase();
    final problem = colon <= 0 || value.isEmpty
        ? ServerHeaderProblem.notNameValue
        : !_headerName.hasMatch(name)
        ? ServerHeaderProblem.badName
        : !_headerValue.hasMatch(value)
        ? ServerHeaderProblem.badValue
        : _reservedNames.contains(lowered) ||
              lowered == anchorProtocolHeader.toLowerCase()
        ? ServerHeaderProblem.reservedName
        : !seen.add(lowered)
        ? ServerHeaderProblem.repeatedName
        : null;
    if (problem != null) {
      errors.add((line: i + 1, problem: problem));
    } else {
      headers[name] = value;
    }
  }
  return (headers: headers, errors: errors);
}
