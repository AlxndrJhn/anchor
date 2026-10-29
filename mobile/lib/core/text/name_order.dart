/// Compares names the way the web app sorts them (its English collator):
/// spaces and symbols first, then digits, then letters, ignoring
/// accents and case; ties go unaccented first, then lowercase first.
/// Latin letters, digits and ASCII symbols match the web exactly; other
/// scripts follow Unicode order.
int compareNames(String a, String b) => _NameKey(a).compareTo(_NameKey(b));

/// [items] in name order.
List<T> sortedByName<T>(Iterable<T> items, String Function(T) nameOf) {
  final keyed = [
    for (final item in items) (item: item, key: _NameKey(nameOf(item))),
  ]..sort((a, b) => a.key.compareTo(b.key));
  return [for (final entry in keyed) entry.item];
}

class _NameKey implements Comparable<_NameKey> {
  factory _NameKey(String name) {
    final lower = name.toLowerCase();
    return _NameKey._(name, lower, _weightsOf(lower));
  }

  const _NameKey._(this.name, this.lower, this.weights);

  final String name;
  final String lower;
  final List<int> weights;

  @override
  int compareTo(_NameKey other) {
    final length = weights.length < other.weights.length
        ? weights.length
        : other.weights.length;
    for (var i = 0; i < length; i++) {
      if (weights[i] != other.weights[i]) return weights[i] - other.weights[i];
    }
    if (weights.length != other.weights.length) {
      return weights.length - other.weights.length;
    }
    final byAccents = lower.compareTo(other.lower);
    if (byAccents != 0) return byAccents;
    return other.name.compareTo(name);
  }
}

// ASCII symbols in the web collator's order.
const _symbolOrder = ' _-,;:!?.\'"()[]{}@*/\\&#%`^+<=>|~\$';

// Digits weigh more than any symbol, and letters more than any digit.
const _digits = 0x110000;
const _letters = 2 * _digits;

final _letter = RegExp(r'\p{L}', unicode: true);
final _digit = RegExp(r'\p{N}', unicode: true);
final _mark = RegExp(r'\p{M}', unicode: true);
final _space = RegExp(r'\s');

List<int> _weightsOf(String lower) {
  final weights = <int>[];
  for (final rune in lower.runes) {
    final char = String.fromCharCode(rune);
    final plain = _plainLetters[char];
    if (plain != null) {
      weights.addAll(plain.runes.map((letter) => _letters + letter));
    } else if (_letter.hasMatch(char)) {
      weights.add(_letters + rune);
    } else if (_digit.hasMatch(char)) {
      weights.add(_digits + rune);
    } else if (_mark.hasMatch(char)) {
      // An accent typed as its own mark counts only in the accent tie-break.
      continue;
    } else if (_space.hasMatch(char)) {
      weights.add(0);
    } else if (_symbolOrder.contains(char)) {
      weights.add(_symbolOrder.indexOf(char));
    } else {
      weights.add(_symbolOrder.length + rune);
    }
  }
  return weights;
}

// Accented Latin letters and the plain letters they sort as.
final Map<String, String> _plainLetters = {
  for (final MapEntry(key: plain, value: accented) in const {
    'a': 'àáâãäåāăąǎǟǡǻȁȃȧ',
    'c': 'çćĉċč',
    'd': 'ðďđ',
    'e': 'èéêëēĕėęěȅȇȩ',
    'g': 'ĝğġģǧǵ',
    'h': 'ĥħȟ',
    'i': 'ìíîïĩīĭįǐȉȋ',
    'j': 'ĵǰ',
    'k': 'ķǩ',
    'l': 'ĺļľŀł',
    'n': 'ñńņňǹ',
    'o': 'òóôõöøōŏőơǒǫǭǿȍȏȫȭȯȱ',
    'r': 'ŕŗřȑȓ',
    's': 'śŝşšſș',
    't': 'ţťț',
    'u': 'ùúûüũūŭůűųưǔǖǘǚǜȕȗ',
    'w': 'ŵ',
    'y': 'ýÿŷȳ',
    'z': 'źżž',
  }.entries)
    for (final char in accented.split('')) char: plain,
  'ß': 'ss',
  'æ': 'ae',
  'ǣ': 'ae',
  'ǽ': 'ae',
  'œ': 'oe',
  'ĳ': 'ij',
  'ǆ': 'dz',
  'ǳ': 'dz',
  'ǉ': 'lj',
  'ǌ': 'nj',
};
