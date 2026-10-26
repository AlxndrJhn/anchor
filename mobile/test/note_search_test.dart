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
}
