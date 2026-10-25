import 'package:anchor/features/notes/domain/note.dart';
import 'package:anchor/features/notes/presentation/notes_view_options.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Note note(String id, int day, {double? position, bool pinned = false}) =>
      Note(
        id: id,
        title: id,
        createdAt: DateTime.utc(2026, 1, day),
        position: position,
        isPinned: pinned,
      );

  final a = note('a', 3);
  final b = note('b', 2);
  final c = note('c', 1);
  const custom = NotesViewOptions(sortOption: SortOption.custom);

  List<String> order(List<Note> notes) =>
      ([...notes]..sort(noteComparator(custom))).map((n) => n.id).toList();

  test('starts newest first and follows dragged places', () {
    expect(order([c, a, b]), ['a', 'b', 'c']);
    final moved = c.copyWith(position: notePosition(a) + 1);
    expect(order([moved, a, b]), ['c', 'a', 'b']);
  });

  test('pinned notes stay on top', () {
    final pinnedC = c.copyWith(isPinned: true);
    expect(order([a, b, pinnedC]), ['c', 'a', 'b']);
  });

  test('a dropped note lands between its new neighbours', () {
    final ordered = [a, b, c];
    expect(
      positionForDrop(ordered, 'c', 'b', before: true),
      (notePosition(a) + notePosition(b)) / 2,
    );
    expect(
      positionForDrop(ordered, 'c', 'a', before: true),
      notePosition(a) + 1000,
    );
    expect(
      positionForDrop(ordered, 'a', 'c', before: false),
      notePosition(c) - 1000,
    );
    expect(positionForDrop(ordered, 'a', 'zz', before: false), isNull);
  });
}
