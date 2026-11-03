import 'dart:convert';

/// A camera or screen of another device, shown live in a note's text: a
/// Delta embed, `{"live-image": "{\"id\":…,\"source\":\"camera\",…}"}`, as
/// the web app writes it (web/features/notes/live-images.ts). This app shows
/// it; the video comes straight from [device].
class LiveImage {
  static const embedType = 'live-image';

  final String id;

  /// 'camera' or 'screen'.
  final String source;

  /// The device that shows its camera or screen.
  final String device;

  /// That device's name, e.g. "Chrome on Windows"; null when unknown.
  final String? label;

  /// A share of the text's width, 0 to 1; null for the full width.
  final double? width;

  /// The part of the video shown; null for all of it.
  final LiveCrop? crop;

  const LiveImage({
    required this.id,
    required this.source,
    required this.device,
    this.label,
    this.width,
    this.crop,
  });

  bool get isScreen => source == 'screen';

  /// The embed's data, as the web app writes it.
  String encode() => jsonEncode({
    'id': id,
    'source': source,
    'device': device,
    'label': ?label,
    if (width != null) 'width': double.parse(width!.toStringAsFixed(3)),
    if (crop != null)
      'crop': {
        'left': crop!.left,
        'top': crop!.top,
        'right': crop!.right,
        'bottom': crop!.bottom,
      },
  });

  /// Null when [data] isn't a live image's.
  static LiveImage? tryParse(Object? data) {
    if (data is! String) return null;
    try {
      final json = jsonDecode(data);
      if (json is! Map) return null;
      final id = json['id'];
      final device = json['device'];
      if (id is! String || id.isEmpty) return null;
      if (device is! String || device.trim().isEmpty) return null;
      final label = json['label'];
      final width = json['width'];
      return LiveImage(
        id: id,
        source: json['source'] == 'screen' ? 'screen' : 'camera',
        device: device.trim(),
        label: label is String && label.trim().isNotEmpty ? label.trim() : null,
        width: width is num && width > 0 && width < 1 ? width.toDouble() : null,
        crop: LiveCrop.tryParse(json['crop']),
      );
    } catch (_) {
      return null;
    }
  }
}

/// A part of a video, in shares (0 to 1) of its width and height.
class LiveCrop {
  final double left;
  final double top;
  final double right;
  final double bottom;

  const LiveCrop(this.left, this.top, this.right, this.bottom);

  static const whole = LiveCrop(0, 0, 1, 1);

  double get across => right - left;
  double get down => bottom - top;

  static LiveCrop? tryParse(Object? data) {
    if (data is! Map) return null;
    final sides = [data['left'], data['top'], data['right'], data['bottom']];
    if (sides.any((side) => side is! num || side < 0 || side > 1)) return null;
    final [l, t, r, b] = [for (final side in sides) (side as num).toDouble()];
    final crop = LiveCrop(
      l < r ? l : r,
      t < b ? t : b,
      l < r ? r : l,
      t < b ? b : t,
    );
    if (crop.across < 0.01 || crop.down < 0.01) return null;
    final isWhole =
        crop.left <= 0.001 &&
        crop.top <= 0.001 &&
        crop.right >= 0.999 &&
        crop.bottom >= 0.999;
    return isWhole ? null : crop;
  }
}
