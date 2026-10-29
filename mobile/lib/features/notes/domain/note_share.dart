import 'package:freezed_annotation/freezed_annotation.dart';
import 'note_share_permission.dart';
import 'user_summary.dart';

part 'note_share.freezed.dart';
part 'note_share.g.dart';

@freezed
abstract class NoteShare with _$NoteShare {
  const factory NoteShare({
    required String id,
    required UserSummary sharedWithUser,
    required NoteSharePermission permission,
    required String createdAt,
    required String updatedAt,
  }) = _NoteShare;

  factory NoteShare.fromJson(Map<String, dynamic> json) =>
      _$NoteShareFromJson(json);
}
