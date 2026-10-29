import 'package:anchor/features/notes/domain/note.dart';
import 'package:anchor/features/notes/domain/note_history.dart';
import 'package:anchor/features/notes/domain/note_revision.dart';
import 'package:anchor/features/notes/domain/user_summary.dart';
import 'package:anchor/features/notes/presentation/note_labels.dart';
import 'package:anchor/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

final _english = lookupAppLocalizations(const Locale('en'));

NoteRevision revisionOf({
  required String id,
  RevisionCause cause = RevisionCause.edit,
  DateTime? createdAt,
  UserSummary? author,
}) => NoteRevision(
  id: id,
  noteId: 'n1',
  version: 1,
  title: '',
  cause: cause,
  createdAt: createdAt ?? DateTime(2026, 8, 18, 10),
  author: author,
);

const ada = UserSummary(id: 'u1', name: 'Ada', email: 'ada@x.dev');
const bob = UserSummary(id: 'u2', name: 'Bob', email: 'bob@x.dev');

void main() {
  group('comparisonTarget', () {
    test('reads a version against the next newer one', () {
      final revisions = [revisionOf(id: 'r2'), revisionOf(id: 'r1')];

      expect(comparisonTarget(revisions, 'r1')?.id, 'r2');
    });

    test('reads the newest version against the note itself', () {
      final revisions = [revisionOf(id: 'r2'), revisionOf(id: 'r1')];

      expect(comparisonTarget(revisions, 'r2'), isNull);
    });

    test('skips versions that never reached the note', () {
      final revisions = [
        revisionOf(id: 'r3', cause: RevisionCause.conflict),
        revisionOf(id: 'r2', cause: RevisionCause.conflict),
        revisionOf(id: 'r1'),
      ];

      expect(comparisonTarget(revisions, 'r1'), isNull);
    });

    test('reads a version that was never saved against the note', () {
      final revisions = [
        revisionOf(id: 'r2'),
        revisionOf(id: 'r1', cause: RevisionCause.conflict),
      ];

      expect(comparisonTarget(revisions, 'r1'), isNull);
    });
  });

  group('historyHasMultipleAuthors', () {
    test('is false when one person wrote everything', () {
      expect(
        historyHasMultipleAuthors([
          revisionOf(id: 'r2', author: ada),
          revisionOf(id: 'r1', author: ada),
        ]),
        isFalse,
      );
    });

    test('is true once someone else appears', () {
      expect(
        historyHasMultipleAuthors([
          revisionOf(id: 'r2', author: bob),
          revisionOf(id: 'r1', author: ada),
        ]),
        isTrue,
      );
    });

    test('counts a missing author as its own', () {
      expect(
        historyHasMultipleAuthors([
          revisionOf(id: 'r2'),
          revisionOf(id: 'r1', author: ada),
        ]),
        isTrue,
      );
    });
  });

  test('revisionAuthorName says You for the reader', () {
    final revision = revisionOf(id: 'r1', author: ada);

    expect(revisionAuthorName(revision, 'u1', _english), 'You');
    expect(revisionAuthorName(revision, 'u2', _english), 'Ada');
    expect(revisionAuthorName(revisionOf(id: 'r1'), 'u1', _english), 'Someone');
  });

  test('groupRevisionsByDay keeps the order and splits on the day', () {
    final days = groupRevisionsByDay([
      revisionOf(id: 'r3', createdAt: DateTime(2026, 8, 18, 10)),
      revisionOf(id: 'r2', createdAt: DateTime(2026, 8, 18, 9)),
      revisionOf(id: 'r1', createdAt: DateTime(2026, 8, 17, 9)),
    ]);

    expect(days.map((day) => day.date), [
      DateTime(2026, 8, 18, 10),
      DateTime(2026, 8, 17, 9),
    ]);
    expect(days.first.revisions.map((r) => r.id), ['r3', 'r2']);
    expect(days.last.revisions.map((r) => r.id), ['r1']);
  });

  test('each kind of version has its own name', () {
    expect(
      revisionLabel(RevisionCause.edit, _english),
      _english.historyEarlier,
    );
    expect(revisionLabel(RevisionCause.restore, _english), 'Before a restore');
  });

  group('what changed after a version', () {
    String delta(String text) => '{"ops":[{"insert":"$text\\n"}]}';
    NoteRevision version(String id, String title, String text) =>
        revisionOf(id: id).copyWith(title: title, content: delta(text));

    test('reads a version against the next one, then the note', () {
      final revisions = [
        version('r2', 'Shop', 'milk\\neggs'),
        version('r1', 'Shop', 'milk'),
      ];
      final note = Note(id: 'n1', title: 'Shopping', content: delta('milk'));
      final changes = VersionChanges();

      final older = changes.of(revisions, revisions[1], note);
      expect(older.target?.id, 'r2');
      expect(older.diff.added, 1);
      expect(older.isTitleChangedFrom(revisions[1].title), isFalse);

      final newest = changes.of(revisions, revisions[0], note);
      expect(newest.target, isNull);
      expect(newest.diff.removed, 1);
      expect(newest.isTitleChangedFrom(revisions[0].title), isTrue);
    });

    test('works a pair out once, and again when the note changes', () {
      final revisions = [version('r1', 'Shop', 'milk')];
      final note = Note(id: 'n1', title: 'Shop', content: delta('milk'));
      final changes = VersionChanges();

      final first = changes.of(revisions, revisions[0], note).diff;
      expect(
        identical(changes.of(revisions, revisions[0], note).diff, first),
        isTrue,
      );
      final edited = note.copyWith(content: delta('bread'));
      expect(
        identical(changes.of(revisions, revisions[0], edited).diff, first),
        isFalse,
      );
      expect(changes.current(note).isUnchanged, isTrue);
    });

    test('a blank title and no title are the same title', () {
      final revisions = [version('r1', '  ', 'milk')];
      final note = Note(id: 'n1', title: '', content: delta('milk'));

      expect(
        VersionChanges()
            .of(revisions, revisions[0], note)
            .isTitleChangedFrom(revisions[0].title),
        isFalse,
      );
    });
  });
}
