/// `manifest.json` next to its files; keep `ShareFolder.swift` in step.
class ShareEntry {
  const ShareEntry({
    required this.id,
    required this.userId,
    required this.savedAt,
    this.title = '',
    this.text = '',
    this.link,
    this.tagIds = const [],
    this.files = const [],
  });

  static const version = 1;

  /// Also the note's id.
  final String id;
  final String userId;
  final DateTime savedAt;
  final String title;
  final String text;

  /// Added as a link after [text].
  final String? link;
  final List<String> tagIds;
  final List<ShareFile> files;

  Map<String, Object?> toJson() => {
    'version': version,
    'id': id,
    'userId': userId,
    'savedAt': savedAt.toUtc().toIso8601String(),
    'title': title,
    'text': text,
    'link': link,
    'tagIds': tagIds,
    'files': [for (final file in files) file.toJson()],
  };

  /// Null when [json] isn't an entry this version can read.
  static ShareEntry? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final version = json['version'];
    final id = json['id'];
    final userId = json['userId'];
    final savedAt = DateTime.tryParse('${json['savedAt']}');
    if (version is! int || version > ShareEntry.version) return null;
    if (id is! String || id.isEmpty || userId is! String || savedAt == null) {
      return null;
    }
    final link = json['link'];
    return ShareEntry(
      id: id,
      userId: userId,
      savedAt: savedAt,
      title: _string(json['title']),
      text: _string(json['text']),
      link: link is String && link.isNotEmpty ? link : null,
      tagIds: [
        for (final tagId in _list(json['tagIds']))
          if (tagId is String) tagId,
      ],
      files: [
        for (final file in _list(json['files'])) ?ShareFile.fromJson(file),
      ],
    );
  }
}

class ShareFile {
  const ShareFile({required this.file, required this.name, required this.mime});

  /// The file's name in the entry's folder.
  final String file;

  /// The name it had in the app it came from.
  final String name;
  final String mime;

  Map<String, Object?> toJson() => {'file': file, 'name': name, 'mime': mime};

  static ShareFile? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final file = json['file'];
    final name = json['name'];
    final mime = json['mime'];
    if (file is! String || name is! String || mime is! String) return null;
    // Only a plain name inside the entry's folder.
    if (file.isEmpty || file.contains('/') || file.startsWith('.')) {
      return null;
    }
    return ShareFile(file: file, name: name, mime: mime);
  }
}

String _string(Object? value) => value is String ? value : '';

List<Object?> _list(Object? value) => value is List ? value : const [];
