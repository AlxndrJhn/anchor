import 'package:anchor/features/notes/domain/note.dart';
import 'package:anchor/features/notes/presentation/note_search.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const note = Note(
    id: 'n1',
    title: 'Groceries',
    content: '{"ops":[{"insert":"Milk and bread\\n"}]}',
  );

  test('finds the query in the title or the text', () {
    expect(noteMatchesSearch(note, 'groceries'), isTrue);
    expect(noteMatchesSearch(note, ' BREAD '), isTrue);
    expect(noteMatchesSearch(note, 'dentist'), isFalse);
  });

  test('finds the query in the text read from the note\'s pictures', () {
    final withPicture = note.copyWith(pictureText: 'Call the Dentist');
    expect(noteMatchesSearch(withPicture, 'dentist'), isTrue);
  });

  test('every note matches an empty query', () {
    expect(noteMatchesSearch(note, '  '), isTrue);
  });

  group('search options', () {
    test('match case', () {
      const options = SearchOptions(matchCase: true);
      expect(noteMatchesSearch(note, 'Groceries', options: options), isTrue);
      expect(noteMatchesSearch(note, 'groceries', options: options), isFalse);
    });

    test('a regular expression, in any case unless asked', () {
      const regex = SearchOptions(regex: true);
      expect(noteMatchesSearch(note, r'milk\s+and', options: regex), isTrue);
      expect(noteMatchesSearch(note, '^GROC', options: regex), isTrue);
      expect(
        noteMatchesSearch(
          note,
          '^GROC',
          options: const SearchOptions(regex: true, matchCase: true),
        ),
        isFalse,
      );
      expect(noteMatchesSearch(note, r'\d+', options: regex), isFalse);
    });

    test('without regex, regex characters are just text', () {
      final priced = note.copyWith(title: 'Milk (2.50)');
      expect(noteMatchesSearch(priced, '(2.50)'), isTrue);
      expect(noteMatchesSearch(note, 'milk.and'), isFalse);
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

    test('travel to an opened note as query parameters', () {
      const options = SearchOptions(regex: true, matchCase: true);
      expect(
        SearchOptions.fromQueryParameters(options.queryParameters),
        options,
      );
      expect(const SearchOptions().queryParameters, isEmpty);
    });
  });
}
