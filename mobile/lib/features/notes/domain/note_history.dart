import 'note.dart';
import 'note_dates.dart';
import 'note_revision.dart';
import 'version_diff.dart';

/// Stands in for a revision id to read the note as it is now.
const String currentVersionId = 'current';

typedef RestoredVersion = ({
  String previousTitle,
  String? previousContent,
  NoteRevision revision,
});

/// How many lines a version added, removed and changed.
typedef LineCounts = ({int added, int removed, int changed});

class HistoryDay {
  const HistoryDay({required this.date, required this.revisions});

  final DateTime date;
  final List<NoteRevision> revisions;
}

bool historyHasMultipleAuthors(List<NoteRevision> revisions) =>
    revisions
        .map((revision) => revision.author?.id ?? 'unknown')
        .toSet()
        .length >
    1;

/// The next newer version that reached the note, or null for the note as it
/// is now. Conflict copies are never targets and always read against the note.
NoteRevision? comparisonTarget(
  List<NoteRevision> revisions,
  String revisionId,
) {
  final index = revisions.indexWhere((revision) => revision.id == revisionId);
  if (index < 0 || revisions[index].cause == RevisionCause.conflict) {
    return null;
  }

  for (var i = index - 1; i >= 0; i--) {
    if (revisions[i].cause != RevisionCause.conflict) return revisions[i];
  }
  return null;
}

List<HistoryDay> groupRevisionsByDay(List<NoteRevision> revisions) {
  final days = <HistoryDay>[];
  DateTime? currentDate;

  for (final revision in revisions) {
    final date = revision.createdAtLocal;
    if (currentDate != null && isSameDay(currentDate, date)) {
      days.last.revisions.add(revision);
      continue;
    }
    currentDate = date;
    days.add(HistoryDay(date: date, revisions: [revision]));
  }

  return days;
}

class VersionChange {
  const VersionChange({
    required this.diff,
    required this.target,
    required this.nextTitle,
  });

  final VersionDiff diff;

  /// Null for the note as it is now.
  final NoteRevision? target;

  /// Null when the note isn't here.
  final String? nextTitle;

  bool isTitleChangedFrom(String title) =>
      nextTitle != null && storedTitleOf(nextTitle!) != storedTitleOf(title);

  /// A new title counts as one more changed line.
  LineCounts lineCountsFrom(String title) => (
    added: diff.added,
    removed: diff.removed,
    changed: diff.changed + (isTitleChangedFrom(title) ? 1 : 0),
  );
}

class VersionChanges {
  final Map<(String, String?, String?), VersionDiff> _diffs = {};

  VersionChange of(
    List<NoteRevision> revisions,
    NoteRevision revision,
    Note? note,
  ) {
    final target = comparisonTarget(revisions, revision.id);
    final after = target?.content ?? note?.content;
    final diff = _diffs.putIfAbsent((
      revision.id,
      target?.id,
      after,
    ), () => diffVersions(revision.content, after));
    return VersionChange(
      diff: diff,
      target: target,
      nextTitle: target?.title ?? note?.title,
    );
  }

  VersionDiff current(Note? note) => _diffs.putIfAbsent((
    currentVersionId,
    null,
    note?.content,
  ), () => diffVersions(note?.content, note?.content));
}
