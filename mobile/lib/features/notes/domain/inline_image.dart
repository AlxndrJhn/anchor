import 'dart:convert';

/// A picture placed in a note's text: a Delta block embed naming one of the
/// note's attachments, `{"note-image": "{\"id\":…,\"width\":…}"}`. The web
/// app reads the same embed.
class InlineImage {
  static const embedType = 'note-image';

  /// Narrowest a picture can be made, as a share of the text's width.
  static const minWidth = 0.2;

  /// The attachment the picture shows.
  final String id;

  /// A share of the text's width, 0 to 1; null for the full width.
  final double? width;

  /// Text shown under the picture; null for none.
  final String? caption;

  const InlineImage({required this.id, this.width, this.caption});

  /// Null when [data] isn't an inline picture's.
  static InlineImage? tryParse(Object? data) {
    if (data is! String) return null;
    try {
      final json = jsonDecode(data);
      if (json is! Map || json['id'] is! String) return null;
      final width = json['width'];
      final caption = json['caption'];
      return InlineImage(
        id: json['id'] as String,
        width: width is num && width > 0 && width <= 1
            ? width.toDouble()
            : null,
        caption: caption is String && caption.trim().isNotEmpty
            ? caption
            : null,
      );
    } catch (_) {
      return null;
    }
  }

  /// The embed's data.
  String encode() => jsonEncode({
    'id': id,
    if (width != null) 'width': double.parse(width!.toStringAsFixed(3)),
    if (caption != null) 'caption': caption,
  });

  InlineImage copyWith({
    String? id,
    double? Function()? width,
    String? Function()? caption,
  }) => InlineImage(
    id: id ?? this.id,
    width: width == null ? this.width : width(),
    caption: caption == null ? this.caption : caption(),
  );
}

/// The attachment ids the pictures in a note's [content] show.
Set<String> inlineImageIds(String? content) {
  if (content == null || !content.contains(InlineImage.embedType)) {
    return const {};
  }
  try {
    final json = jsonDecode(content);
    final ops = json is Map ? json['ops'] : null;
    if (ops is! List) return const {};
    return {
      for (final op in ops)
        if (op is Map && op['insert'] is Map)
          ?InlineImage.tryParse(
            (op['insert'] as Map)[InlineImage.embedType],
          )?.id,
    };
  } catch (_) {
    return const {};
  }
}
