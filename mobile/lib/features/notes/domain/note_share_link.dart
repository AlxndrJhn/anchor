import 'note_share_permission.dart';

/// A link that opens the note without an account, on the server's web app.
class NoteShareLink {
  const NoteShareLink({required this.token, required this.permission});

  final String token;
  final NoteSharePermission permission;

  factory NoteShareLink.fromJson(Map<String, dynamic> json) => NoteShareLink(
    token: json['token'] as String,
    permission: NoteSharePermission.fromString(json['permission'] as String),
  );

  /// Where the link opens the note: the web app the server serves.
  String urlOn(String serverUrl) =>
      '${serverUrl.replaceAll(RegExp(r'/+$'), '')}/s/$token';
}
