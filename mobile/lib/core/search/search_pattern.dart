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
    RegExp literal() =>
        RegExp(RegExp.escape(q), caseSensitive: options.matchCase);
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
