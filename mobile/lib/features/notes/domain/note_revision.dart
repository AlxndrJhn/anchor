import 'package:freezed_annotation/freezed_annotation.dart';

import 'user_summary.dart';

part 'note_revision.freezed.dart';
part 'note_revision.g.dart';

enum RevisionCause {
  edit,
  conflict,
  restore;

  static RevisionCause fromName(String? value) => RevisionCause.values
      .firstWhere((cause) => cause.name == value, orElse: () => edit);
}

@freezed
abstract class NoteRevision with _$NoteRevision {
  const NoteRevision._();

  const factory NoteRevision({
    required String id,
    required String noteId,
    required int version,
    required String title,
    @JsonKey(unknownEnumValue: RevisionCause.edit) required RevisionCause cause,
    required DateTime createdAt,
    UserSummary? author,
    String? content,
  }) = _NoteRevision;

  factory NoteRevision.fromJson(Map<String, dynamic> json) =>
      _$NoteRevisionFromJson(json);

  DateTime get createdAtLocal => createdAt.toLocal();
}

@freezed
abstract class NoteRevisionPage with _$NoteRevisionPage {
  const factory NoteRevisionPage({
    @Default(<NoteRevision>[]) List<NoteRevision> revisions,
    String? nextCursor,
  }) = _NoteRevisionPage;

  factory NoteRevisionPage.fromJson(Map<String, dynamic> json) =>
      _$NoteRevisionPageFromJson(json);
}
