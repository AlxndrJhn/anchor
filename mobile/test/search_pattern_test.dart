import 'package:anchor/core/search/search_pattern.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const text = 'Groceries: milk and eggs';

  test('plain words, in any case unless asked', () {
    expect(SearchPattern('GROCERIES').hasMatch(text), isTrue);
    const matchCase = SearchOptions(matchCase: true);
    expect(
      SearchPattern('Groceries', options: matchCase).hasMatch(text),
      isTrue,
    );
    expect(
      SearchPattern('groceries', options: matchCase).hasMatch(text),
      isFalse,
    );
  });

  test('a regular expression, in any case unless asked', () {
    const regex = SearchOptions(regex: true);
    expect(SearchPattern(r'milk\s+and', options: regex).hasMatch(text), isTrue);
    expect(SearchPattern('^GROC', options: regex).hasMatch(text), isTrue);
    expect(
      SearchPattern(
        '^GROC',
        options: const SearchOptions(regex: true, matchCase: true),
      ).hasMatch(text),
      isFalse,
    );
    expect(SearchPattern(r'\d+', options: regex).hasMatch(text), isFalse);
  });

  test('without regex, regex characters are just text', () {
    expect(SearchPattern('(2.50)').hasMatch('Milk (2.50)'), isTrue);
    expect(SearchPattern('milk.and').hasMatch(text), isFalse);
  });

  test('plain words ignore accents', () {
    expect(SearchPattern('apfel').hasMatch('Äpfel kaufen'), isTrue);
    expect(SearchPattern('äpfel').hasMatch('Apfelkuchen'), isTrue);
    expect(SearchPattern('cafe').hasMatch('Café'), isTrue);
    expect(SearchPattern('strasse').hasMatch('Hauptstraße'), isTrue);
    expect(SearchPattern('straße').hasMatch('STRASSE'), isTrue);
    expect(SearchPattern('apfel').hasMatch('Birne'), isFalse);
    const matchCase = SearchOptions(matchCase: true);
    expect(
      SearchPattern('Apfel', options: matchCase).hasMatch('Äpfel'),
      isTrue,
    );
    expect(
      SearchPattern('Apfel', options: matchCase).hasMatch('äpfel'),
      isFalse,
    );
    // Marks the accented word whole.
    expect(
      SearchPattern('apfel').allMatches('Ein Äpfel').map((m) => m[0]),
      ['Äpfel'],
    );
  });

  test('a half-typed regex is looked for as typed meanwhile', () {
    final pattern = SearchPattern(
      '(milk',
      options: const SearchOptions(regex: true),
    );
    expect(pattern.isValid, isFalse);
    expect(pattern.hasMatch('(Milk'), isTrue);
  });

  test('marks every non-empty match', () {
    final pattern = SearchPattern(
      'a*',
      options: const SearchOptions(regex: true),
    );
    expect(pattern.allMatches('baaca').map((m) => (m.start, m.end)), [
      (1, 3),
      (4, 5),
    ]);
  });

  test('nothing typed matches everything', () {
    expect(SearchPattern('  ').isEmpty, isTrue);
    expect(SearchPattern('  ').hasMatch('anything'), isTrue);
  });

  test('travel to an opened note as query parameters', () {
    const options = SearchOptions(regex: true, matchCase: true);
    expect(SearchOptions.fromQueryParameters(options.queryParameters), options);
    expect(const SearchOptions().queryParameters, isEmpty);
    expect(const SearchOptions().isDefault, isTrue);
  });
}
