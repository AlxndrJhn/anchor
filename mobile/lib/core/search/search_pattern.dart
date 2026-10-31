/// Search options and the pattern they make, shared by the notes list and
/// the editor that marks a search's matches.
library;

/// How the search box reads what's typed: as a regular expression, and
/// whether upper and lower case must match.
class SearchOptions {
  const SearchOptions({this.regex = false, this.matchCase = false});

  final bool regex;
  final bool matchCase;

  SearchOptions copyWith({bool? regex, bool? matchCase}) => SearchOptions(
    regex: regex ?? this.regex,
    matchCase: matchCase ?? this.matchCase,
  );

  /// Plain text in any case: the search box as it starts.
  bool get isDefault => !regex && !matchCase;

  static const regexParameter = 'regex';
  static const matchCaseParameter = 'case';

  /// Carried to an opened note, so it marks the same matches.
  Map<String, String> get queryParameters => {
    if (regex) regexParameter: '1',
    if (matchCase) matchCaseParameter: '1',
  };

  static SearchOptions fromQueryParameters(Map<String, String> parameters) =>
      SearchOptions(
        regex: parameters[regexParameter] == '1',
        matchCase: parameters[matchCaseParameter] == '1',
      );

  @override
  bool operator ==(Object other) =>
      other is SearchOptions &&
      other.regex == regex &&
      other.matchCase == matchCase;

  @override
  int get hashCode => Object.hash(regex, matchCase);
}

/// What a search looks for: the typed text, or a regular expression, in
/// any case or the exact one.
class SearchPattern {
  SearchPattern._(this._pattern, {required this.isValid});

  factory SearchPattern(
    String query, {
    SearchOptions options = const SearchOptions(),
  }) {
    final q = query.trim();
    if (q.isEmpty) return SearchPattern._(null, isValid: true);
    RegExp literal() => RegExp(
      _ignoringAccents(q, matchCase: options.matchCase),
      caseSensitive: options.matchCase,
    );
    if (!options.regex) return SearchPattern._(literal(), isValid: true);
    try {
      return SearchPattern._(
        RegExp(q, caseSensitive: options.matchCase, unicode: true),
        isValid: true,
      );
    } on FormatException {
      // Half-typed, like "(ab": looked for as plain text meanwhile.
      return SearchPattern._(literal(), isValid: false);
    }
  }

  final RegExp? _pattern;

  /// False for a regular expression that can't be read; the text is then
  /// looked for as typed.
  final bool isValid;

  /// Nothing to look for: everything matches.
  bool get isEmpty => _pattern == null;

  bool hasMatch(String text) => _pattern?.hasMatch(text) ?? true;

  /// Where it matches in [text], leaving out empty matches (a regular
  /// expression like `a*` matches nothing everywhere).
  Iterable<Match> allMatches(String text) =>
      _pattern?.allMatches(text).where((m) => m.end > m.start) ?? const [];
}

/// Each letter and the accented letters a plain search counts as the same,
/// so "apfel" finds "Äpfel" and "cafe" finds "café".
const _accented = {
  'A': 'ÀÁÂÃÄÅĀĂĄǍǞǠǺȀȂȦḀẠẢẤẦẨẪẬẮẰẲẴẶ',
  'B': 'ḂḄḆ',
  'C': 'ÇĆĈĊČḈ',
  'D': 'ĎḊḌḎḐḒĐ',
  'E': 'ÈÉÊËĒĔĖĘĚȄȆȨḔḖḘḚḜẸẺẼẾỀỂỄỆ',
  'F': 'Ḟ',
  'G': 'ĜĞĠĢǦǴḠ',
  'H': 'ĤȞḢḤḦḨḪĦ',
  'I': 'ÌÍÎÏĨĪĬĮİǏȈȊḬḮỈỊ',
  'J': 'Ĵ',
  'K': 'ĶǨḰḲḴ',
  'L': 'ĹĻĽḶḸḺḼŁ',
  'M': 'ḾṀṂ',
  'N': 'ÑŃŅŇǸṄṆṈṊ',
  'O': 'ÒÓÔÕÖŌŎŐƠǑǪǬȌȎȪȬȮȰṌṎṐṒỌỎỐỒỔỖỘỚỜỞỠỢØ',
  'P': 'ṔṖ',
  'R': 'ŔŖŘȐȒṘṚṜṞ',
  'S': 'ŚŜŞŠȘṠṢṤṦṨ',
  'T': 'ŢŤȚṪṬṮṰ',
  'U': 'ÙÚÛÜŨŪŬŮŰŲƯǓǕǗǙǛȔȖṲṴṶṸṺỤỦỨỪỬỮỰ',
  'V': 'ṼṾ',
  'W': 'ŴẀẂẄẆẈ',
  'X': 'ẊẌ',
  'Y': 'ÝŶŸȲẎỲỴỶỸ',
  'Z': 'ŹŻŽẐẒẔ',
  'a': 'àáâãäåāăąǎǟǡǻȁȃȧḁạảấầẩẫậắằẳẵặ',
  'b': 'ḃḅḇ',
  'c': 'çćĉċčḉ',
  'd': 'ďḋḍḏḑḓđ',
  'e': 'èéêëēĕėęěȅȇȩḕḗḙḛḝẹẻẽếềểễệ',
  'f': 'ḟ',
  'g': 'ĝğġģǧǵḡ',
  'h': 'ĥȟḣḥḧḩḫẖħ',
  'i': 'ìíîïĩīĭįǐȉȋḭḯỉịı',
  'j': 'ĵǰ',
  'k': 'ķǩḱḳḵ',
  'l': 'ĺļľḷḹḻḽł',
  'm': 'ḿṁṃ',
  'n': 'ñńņňǹṅṇṉṋ',
  'o': 'òóôõöōŏőơǒǫǭȍȏȫȭȯȱṍṏṑṓọỏốồổỗộớờởỡợø',
  'p': 'ṕṗ',
  'r': 'ŕŗřȑȓṙṛṝṟ',
  's': 'śŝşšșṡṣṥṧṩ',
  't': 'ţťțṫṭṯṱẗ',
  'u': 'ùúûüũūŭůűųưǔǖǘǚǜȕȗṳṵṷṹṻụủứừửữự',
  'v': 'ṽṿ',
  'w': 'ŵẁẃẅẇẉẘ',
  'x': 'ẋẍ',
  'y': 'ýÿŷȳẏẙỳỵỷỹ',
  'z': 'źżžẑẓẕ',
};

final _letterOf = {
  for (final MapEntry(:key, :value) in _accented.entries)
    for (final accented in value.split('')) accented: key,
};

/// A pattern for [query] as plain text, where every letter also matches its
/// accented forms (typed accented or not). Without [matchCase], "ss" and "ß"
/// match each other too.
String _ignoringAccents(String query, {required bool matchCase}) {
  final letters = [
    for (final rune in query.runes)
      _letterOf[String.fromCharCode(rune)] ?? String.fromCharCode(rune),
  ];
  final pattern = StringBuffer();
  for (var i = 0; i < letters.length; i++) {
    final letter = letters[i];
    if (!matchCase) {
      final pair = i + 1 < letters.length
          ? (letter + letters[i + 1]).toLowerCase()
          : '';
      if (pair == 'ss' || letter == 'ß' || letter == 'ẞ') {
        pattern.write('(?:ss|ß|ẞ)');
        if (pair == 'ss') i++;
        continue;
      }
    }
    final accented = _accented[letter];
    pattern.write(
      accented == null ? RegExp.escape(letter) : '[$letter$accented]',
    );
  }
  return pattern.toString();
}
