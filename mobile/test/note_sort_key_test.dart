import 'package:anchor/features/notes/domain/note.dart';
import 'package:anchor/features/notes/presentation/notes_view_options.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Note note(String id, int day, {double? position, int? positionedDay}) => Note(
    id: id,
    title: id,
    updatedAt: DateTime.utc(2026, 1, day),
    position: position,
    positionedAt: positionedDay == null
        ? null
        : DateTime.utc(2026, 1, positionedDay),
  );

  List<String> order(List<Note> notes, {bool ascending = false}) =>
      ([...notes]
            ..sort(noteComparator(NotesViewOptions(isAscending: ascending))))
          .map((n) => n.id)
          .toList();

  final a = note('a', 3);
  final b = note('b', 2);
  final c = note('c', 1);

  test('sorts by last edit until a note is dragged', () {
    expect(order([c, a, b]), ['a', 'b', 'c']);
  });

  test('keeps a note where it was dragged, as on the web', () {
    final between = (noteSortKey(b) + noteSortKey(c)) / 2;
    final moved = note('a', 3, position: between, positionedDay: 4);
    expect(order([moved, b, c]), ['b', 'a', 'c']);
  });

  test('a note edited after it was dragged goes back to the top', () {
    final edited = note(
      'c',
      5,
      position: noteSortKey(b) - 1000,
      positionedDay: 4,
    );
    expect(order([a, b, edited]), ['c', 'a', 'b']);
  });

  test('oldest first ignores dragged places', () {
    final moved = note('a', 3, position: 0, positionedDay: 4);
    expect(order([moved, b, c], ascending: true), ['c', 'b', 'a']);
  });
}
