// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'note_share.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_NoteShare _$NoteShareFromJson(Map<String, dynamic> json) => _NoteShare(
  id: json['id'] as String,
  sharedWithUser: UserSummary.fromJson(
    json['sharedWithUser'] as Map<String, dynamic>,
  ),
  permission: $enumDecode(_$NoteSharePermissionEnumMap, json['permission']),
  createdAt: json['createdAt'] as String,
  updatedAt: json['updatedAt'] as String,
);

Map<String, dynamic> _$NoteShareToJson(_NoteShare instance) =>
    <String, dynamic>{
      'id': instance.id,
      'sharedWithUser': instance.sharedWithUser,
      'permission': _$NoteSharePermissionEnumMap[instance.permission]!,
      'createdAt': instance.createdAt,
      'updatedAt': instance.updatedAt,
    };

const _$NoteSharePermissionEnumMap = {
  NoteSharePermission.viewer: 'viewer',
  NoteSharePermission.editor: 'editor',
};
