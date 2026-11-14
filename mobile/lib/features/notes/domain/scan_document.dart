import 'dart:convert';
import 'dart:ui' show Offset;

/// How a scanned page's colours come out.
enum ScanProfile {
  /// Black and white only: crisp text, smallest PDF.
  bw('bw'),

  /// The board turned white and the marker colours made stronger.
  whiteboard('whiteboard'),

  /// The paper evened out to white, text and its colours kept.
  text('text'),

  /// As photographed, only straightened.
  color('color');

  const ScanProfile(this.code);

  final String code;

  static ScanProfile parse(Object? value) =>
      values.firstWhere((p) => p.code == value, orElse: () => ScanProfile.text);
}

/// The paper a scan's PDF is laid out on.
enum PdfPaper {
  a4('a4'),
  letter('letter'),

  /// Each PDF page as big as its picture.
  fit('fit');

  const PdfPaper(this.code);

  final String code;

  static PdfPaper parse(Object? value) =>
      values.firstWhere((p) => p.code == value, orElse: () => PdfPaper.a4);
}

/// How sharp (and big) a scan's PDF is.
enum PdfQuality {
  small('small', longSide: 1240, jpegQuality: 60, dpi: 110),
  standard('standard', longSide: 1754, jpegQuality: 80, dpi: 150),
  high('high', longSide: 2480, jpegQuality: 92, dpi: 220);

  const PdfQuality(
    this.code, {
    required this.longSide,
    required this.jpegQuality,
    required this.dpi,
  });

  final String code;

  /// The longest a page's picture is, in pixels.
  final int longSide;
  final int jpegQuality;

  /// Pixels per inch, for [PdfPaper.fit].
  final int dpi;

  static PdfQuality parse(Object? value) => values.firstWhere(
    (q) => q.code == value,
    orElse: () => PdfQuality.standard,
  );
}

/// One photographed page: the untouched photo (an attachment) and how it's
/// turned into the page, so it can be changed again on any device.
class ScanPage {
  const ScanPage({
    required this.id,
    this.corners,
    this.rotate = 0,
    this.profile = ScanProfile.text,
    this.brightness = 0,
    this.contrast = 0,
    this.threshold = 0,
    this.cleanup = defaultCleanup,
  });

  static const defaultCleanup = 50;

  /// The attachment holding the photo, never changed.
  final String id;

  /// The page's corners as shares of the photo as shown, top left first and
  /// on clockwise; null for the whole photo.
  final List<Offset>? corners;

  /// Quarter turns clockwise, in degrees: 0, 90, 180 or 270.
  final int rotate;
  final ScanProfile profile;

  /// -100 to 100.
  final int brightness;

  /// -100 to 100.
  final int contrast;

  /// -100 to 100, black and white only: higher makes more of it black.
  final int threshold;

  /// 0 to 100: how strongly the paper's shading is evened out.
  final int cleanup;

  ScanPage copyWith({
    String? id,
    List<Offset>? Function()? corners,
    int? rotate,
    ScanProfile? profile,
    int? brightness,
    int? contrast,
    int? threshold,
    int? cleanup,
  }) => ScanPage(
    id: id ?? this.id,
    corners: corners == null ? this.corners : corners(),
    rotate: rotate ?? this.rotate,
    profile: profile ?? this.profile,
    brightness: brightness ?? this.brightness,
    contrast: contrast ?? this.contrast,
    threshold: threshold ?? this.threshold,
    cleanup: cleanup ?? this.cleanup,
  );

  /// The page turned a quarter: [clockwise] or back.
  ScanPage turned({bool clockwise = true}) =>
      copyWith(rotate: (rotate + (clockwise ? 90 : 270)) % 360);

  /// This page's look (profile and sliders) given to [other].
  ScanPage lookOnto(ScanPage other) => other.copyWith(
    profile: profile,
    brightness: brightness,
    contrast: contrast,
    threshold: threshold,
    cleanup: cleanup,
  );

  /// Whether [other] looks the same: everything but the photo.
  bool sameLook(ScanPage other) =>
      profile == other.profile &&
      brightness == other.brightness &&
      contrast == other.contrast &&
      threshold == other.threshold &&
      cleanup == other.cleanup;

  /// A key that changes whenever the page would come out differently.
  String get renderKey => jsonEncode(toJson());

  static ScanPage? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    if (id is! String || id.isEmpty) return null;
    return ScanPage(
      id: id,
      corners: _corners(json['corners']),
      rotate: switch (json['rotate']) {
        final num r =>
          const [0, 90, 180, 270].contains(r.round() % 360)
              ? r.round() % 360
              : 0,
        _ => 0,
      },
      profile: ScanProfile.parse(json['profile']),
      brightness: _level(json['brightness'], 0),
      contrast: _level(json['contrast'], 0),
      threshold: _level(json['threshold'], 0),
      cleanup: switch (json['cleanup']) {
        final num c => c.round().clamp(0, 100),
        _ => defaultCleanup,
      },
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    if (corners case final c?)
      'corners': [
        for (final p in c) [_round(p.dx), _round(p.dy)],
      ],
    if (rotate != 0) 'rotate': rotate,
    if (profile != ScanProfile.text) 'profile': profile.code,
    if (brightness != 0) 'brightness': brightness,
    if (contrast != 0) 'contrast': contrast,
    if (threshold != 0) 'threshold': threshold,
    if (cleanup != defaultCleanup) 'cleanup': cleanup,
  };

  static int _level(Object? value, int fallback) => switch (value) {
    final num v => v.round().clamp(-100, 100),
    _ => fallback,
  };

  static double _round(double v) =>
      (v.clamp(0.0, 1.0) * 10000).roundToDouble() / 10000;

  static List<Offset>? _corners(Object? value) {
    if (value is! List || value.length != 4) return null;
    final out = <Offset>[];
    for (final p in value) {
      if (p is! List || p.length != 2 || p[0] is! num || p[1] is! num) {
        return null;
      }
      out.add(
        Offset(
          (p[0] as num).toDouble().clamp(0.0, 1.0),
          (p[1] as num).toDouble().clamp(0.0, 1.0),
        ),
      );
    }
    return out;
  }
}

/// How a scan's PDF is laid out.
class PdfSettings {
  const PdfSettings({
    this.paper = PdfPaper.a4,
    this.margin = 0,
    this.quality = PdfQuality.standard,
  });

  static const margins = [0, 5, 10, 15];

  final PdfPaper paper;

  /// Millimetres around each picture: 0, 5, 10 or 15.
  final int margin;
  final PdfQuality quality;

  bool get isDefault =>
      paper == PdfPaper.a4 && margin == 0 && quality == PdfQuality.standard;

  PdfSettings copyWith({PdfPaper? paper, int? margin, PdfQuality? quality}) =>
      PdfSettings(
        paper: paper ?? this.paper,
        margin: margin ?? this.margin,
        quality: quality ?? this.quality,
      );

  static PdfSettings fromJson(Object? json) {
    if (json is! Map) return const PdfSettings();
    final margin = json['margin'];
    return PdfSettings(
      paper: PdfPaper.parse(json['size']),
      margin: margin is num && margins.contains(margin.round())
          ? margin.round()
          : 0,
      quality: PdfQuality.parse(json['quality']),
    );
  }

  Map<String, Object?> toJson() => {
    'size': paper.code,
    'margin': margin,
    'quality': quality.code,
  };

  @override
  bool operator ==(Object other) =>
      other is PdfSettings &&
      other.paper == paper &&
      other.margin == margin &&
      other.quality == quality;

  @override
  int get hashCode => Object.hash(paper, margin, quality);
}

/// Pages scanned with the phone, placed in a note's text: a Delta embed,
/// `{"scan": "{\"pages\":[…]}"}`, as the web app writes it too
/// (web/features/notes/scans.ts). Only the photos and the settings are kept;
/// each device makes the pages and the PDF from them.
class ScanDocument {
  const ScanDocument({
    required this.pages,
    this.title = '',
    this.pdf = const PdfSettings(),
  });

  static const embedType = 'scan';

  final List<ScanPage> pages;

  /// Names the PDF; may be empty.
  final String title;
  final PdfSettings pdf;

  ScanDocument copyWith({
    List<ScanPage>? pages,
    String? title,
    PdfSettings? pdf,
  }) => ScanDocument(
    pages: pages ?? this.pages,
    title: title ?? this.title,
    pdf: pdf ?? this.pdf,
  );

  /// The PDF's file name: the title, or [fallback], made safe for a file.
  String fileName(String fallback) {
    final name = (title.trim().isEmpty ? fallback : title.trim())
        .replaceAll(RegExp(r'[\\/:*?"<>|\n\r\t]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return '${name.isEmpty ? fallback : name}.pdf';
  }

  static ScanDocument? tryParse(Object? value) {
    if (value is! String) return null;
    try {
      final json = jsonDecode(value);
      if (json is! Map) return null;
      final pages = [
        if (json['pages'] case final List list)
          for (final p in list) ?ScanPage.fromJson(p),
      ];
      final title = json['title'];
      return ScanDocument(
        pages: pages,
        title: title is String ? title.trim() : '',
        pdf: PdfSettings.fromJson(json['pdf']),
      );
    } on FormatException {
      return null;
    }
  }

  String encode() => jsonEncode({
    if (title.trim().isNotEmpty) 'title': title.trim(),
    'pages': [for (final p in pages) p.toJson()],
    if (!pdf.isDefault) 'pdf': pdf.toJson(),
  });
}

/// The scans in a note's stored [content], in order.
List<ScanDocument> scansOf(String? content) {
  if (content == null || !content.contains('"${ScanDocument.embedType}"')) {
    return const [];
  }
  try {
    final json = jsonDecode(content);
    final ops = json is Map ? json['ops'] : json;
    if (ops is! List) return const [];
    return [
      for (final op in ops)
        if (op is Map && op['insert'] is Map)
          ?ScanDocument.tryParse((op['insert'] as Map)[ScanDocument.embedType]),
    ];
  } on FormatException {
    return const [];
  }
}

/// The attachments the scans in a note's stored [content] use.
Set<String> scanAttachmentIds(String? content) => {
  for (final scan in scansOf(content)) ...scan.pages.map((p) => p.id),
};
