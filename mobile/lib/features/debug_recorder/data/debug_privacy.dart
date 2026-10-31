/// Keeps what's personal out of a debug report's text, the way
/// `debug_censor.dart` keeps it out of the film: the report says what kind
/// of thing changed, never what the user wrote.
library;

const _hidden = '***';

/// A time, a word of `toString()` output, or the brackets and separators
/// between them. Times go first: their colons aren't separators.
final _token = RegExp(
  '$_time'
  r'|[^\s()\[\]{}<>,:=]+|[\s()\[\]{}<>,:=]+',
);
const _time = r'\d{4}-\d\d-\d\d(?:[T ]\d\d:\d\d(?::\d\d(?:\.\d+)?)?Z?)?';

/// Values that say how the app is, not what's in it.
final _safeValue = RegExp(
  r'^(?:true|false|null|-?\d+(?:\.\d+)?(?:e-?\d+)?'
  r'|[A-Z]\w*\.\w+|\.\w+' // enum values
  '|$_time'
  r'|[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})$', // ids
  caseSensitive: false,
);

final _identifier = RegExp(r'^[A-Za-z_$][\w$]*$');
final _nameEnd = RegExp('[:=(<]');

/// [description], a `toString()` of app state, with only its shape left:
/// type names, field names and plain values such as numbers, flags, enums,
/// times and ids. Every other word is `***`, since a title or a note can't
/// be told from the rest once it's printed.
///
/// `Note(id: 3, title: Shopping, list, pinned: true)` becomes
/// `Note(id: 3, title: ***, ***, pinned: true)`.
String keepShape(String description) {
  final tokens = [for (final m in _token.allMatches(description)) m[0]!];
  final out = <String>[];
  for (var i = 0; i < tokens.length; i++) {
    final t = tokens[i];
    if (!_isWord(t)) {
      out.add(t);
      continue;
    }
    // Code puts nothing between a name and its bracket or colon.
    final next = i + 1 < tokens.length ? tokens[i + 1] : '';
    final isName = _identifier.hasMatch(t) && next.startsWith(_nameEnd);
    if (isName || _safeValue.hasMatch(t)) {
      out.add(t);
      continue;
    }
    // Words hidden one after another are one `***`: how many says nothing.
    final gap = out.isNotEmpty && out.last.trim().isEmpty;
    if (gap && out.length > 1 && out[out.length - 2] == _hidden) {
      out.removeLast();
    } else {
      out.add(_hidden);
    }
  }
  return out.join();
}

bool _isWord(String token) => !RegExp(r'^[\s()\[\]{}<>,:=]').hasMatch(token);

final _email = RegExp(r'[\w.+-]+@[\w-]+(?:\.[\w-]+)+');
final _query = RegExp(r'\?[^\s]+');

/// A log line for the report: its first line only, since what follows is
/// request and response bodies, and no addresses or query strings.
String scrubLogLine(String message) {
  final first = message.split('\n').first;
  return first.replaceAll(_email, _hidden).replaceAll(_query, '?$_hidden');
}

/// [location] with its query's values hidden: searches are what the user
/// typed.
String scrubLocation(String location) {
  final uri = Uri.tryParse(location);
  if (uri == null) return _hidden;
  if (uri.query.isEmpty) return uri.path;
  final keys = uri.queryParametersAll.keys.map((k) => '$k=$_hidden');
  return '${uri.path}?${keys.join('&')}';
}
