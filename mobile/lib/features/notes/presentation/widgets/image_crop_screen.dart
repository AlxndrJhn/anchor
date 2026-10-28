import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/context_extensions.dart';

/// Lets the user pick the part of a picture to keep: drag a corner to
/// resize the frame, or inside it to move it. Returns the frame as shares
/// (0 to 1) of the picture's width and height, or null when cancelled.
class ImageCropScreen extends StatefulWidget {
  final String path;

  const ImageCropScreen({super.key, required this.path});

  static Future<Rect?> open(BuildContext context, String path) =>
      Navigator.of(context).push<Rect>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => ImageCropScreen(path: path),
        ),
      );

  @override
  State<ImageCropScreen> createState() => _ImageCropScreenState();
}

enum _Handle { topLeft, topRight, bottomLeft, bottomRight, move }

class _ImageCropScreenState extends State<ImageCropScreen> {
  /// The picture's size as shown (its EXIF rotation applied).
  Size? _size;
  Rect _area = const Rect.fromLTRB(0, 0, 1, 1);
  _Handle? _dragging;

  static const _minShare = 0.08;
  static const _handleReach = 36.0;

  @override
  void initState() {
    super.initState();
    _measure();
  }

  Future<void> _measure() async {
    final stream = FileImage(
      File(widget.path),
    ).resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener((info, _) {
      stream.removeListener(listener);
      if (!mounted) return;
      setState(
        () => _size = Size(
          info.image.width.toDouble(),
          info.image.height.toDouble(),
        ),
      );
    }, onError: (_, _) => stream.removeListener(listener));
    stream.addListener(listener);
  }

  /// Where the picture sits in a box of [box] size, fitted whole.
  Rect _pictureIn(Size box) {
    final size = _size!;
    final fitted = applyBoxFit(BoxFit.contain, size, box).destination;
    return Alignment.center.inscribe(fitted, Offset.zero & box);
  }

  _Handle _handleAt(Offset at, Rect frame) {
    final corners = {
      _Handle.topLeft: frame.topLeft,
      _Handle.topRight: frame.topRight,
      _Handle.bottomLeft: frame.bottomLeft,
      _Handle.bottomRight: frame.bottomRight,
    };
    for (final MapEntry(:key, :value) in corners.entries) {
      if ((value - at).distance <= _handleReach) return key;
    }
    return _Handle.move;
  }

  void _drag(Offset delta, Rect picture) {
    final dx = delta.dx / picture.width;
    final dy = delta.dy / picture.height;
    var a = _area;
    switch (_dragging) {
      case _Handle.move:
        final left = (a.left + dx).clamp(0.0, 1 - a.width);
        final top = (a.top + dy).clamp(0.0, 1 - a.height);
        a = Rect.fromLTWH(left, top, a.width, a.height);
      case _Handle.topLeft:
        a = Rect.fromLTRB(
          (a.left + dx).clamp(0.0, a.right - _minShare),
          (a.top + dy).clamp(0.0, a.bottom - _minShare),
          a.right,
          a.bottom,
        );
      case _Handle.topRight:
        a = Rect.fromLTRB(
          a.left,
          (a.top + dy).clamp(0.0, a.bottom - _minShare),
          (a.right + dx).clamp(a.left + _minShare, 1.0),
          a.bottom,
        );
      case _Handle.bottomLeft:
        a = Rect.fromLTRB(
          (a.left + dx).clamp(0.0, a.right - _minShare),
          a.top,
          a.right,
          (a.bottom + dy).clamp(a.top + _minShare, 1.0),
        );
      case _Handle.bottomRight:
        a = Rect.fromLTRB(
          a.left,
          a.top,
          (a.right + dx).clamp(a.left + _minShare, 1.0),
          (a.bottom + dy).clamp(a.top + _minShare, 1.0),
        );
      case null:
        return;
    }
    setState(() => _area = a);
  }

  bool get _isWhole =>
      _area.left <= 0.001 &&
      _area.top <= 0.001 &&
      _area.right >= 0.999 &&
      _area.bottom >= 0.999;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(LucideIcons.x),
          tooltip: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Crop'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.rotateCcw),
            tooltip: 'Reset',
            onPressed: _isWhole
                ? null
                : () => setState(() => _area = const Rect.fromLTRB(0, 0, 1, 1)),
          ),
          IconButton(
            icon: const Icon(LucideIcons.check),
            tooltip: 'Crop',
            onPressed: _isWhole ? null : () => Navigator.of(context).pop(_area),
          ),
        ],
      ),
      body: _size == null
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white54),
            )
          : Padding(
              padding: EdgeInsets.all(context.dims.xl),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final picture = _pictureIn(constraints.biggest);
                  final frame = Rect.fromLTRB(
                    picture.left + _area.left * picture.width,
                    picture.top + _area.top * picture.height,
                    picture.left + _area.right * picture.width,
                    picture.top + _area.bottom * picture.height,
                  );
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: (d) =>
                        _dragging = _handleAt(d.localPosition, frame),
                    onPanUpdate: (d) => _drag(d.delta, picture),
                    onPanEnd: (_) => _dragging = null,
                    child: Stack(
                      children: [
                        Positioned.fromRect(
                          rect: picture,
                          child: Image.file(
                            File(widget.path),
                            fit: BoxFit.fill,
                          ),
                        ),
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _FramePainter(
                              frame: frame,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }
}

/// Dims what's cut away, and draws the frame with its corners and thirds.
class _FramePainter extends CustomPainter {
  final Rect frame;
  final Color color;

  const _FramePainter({required this.frame, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final outside = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRect(frame);
    canvas.drawPath(outside, Paint()..color = const Color(0xA6000000));

    final line = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRect(frame, line);

    final thirds = Paint()
      ..color = Colors.white38
      ..strokeWidth = 1;
    for (var i = 1; i < 3; i++) {
      final x = frame.left + frame.width * i / 3;
      final y = frame.top + frame.height * i / 3;
      canvas.drawLine(Offset(x, frame.top), Offset(x, frame.bottom), thirds);
      canvas.drawLine(Offset(frame.left, y), Offset(frame.right, y), thirds);
    }

    final corner = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = ui.StrokeCap.round;
    const arm = 18.0;
    for (final (point, dx, dy) in [
      (frame.topLeft, 1.0, 1.0),
      (frame.topRight, -1.0, 1.0),
      (frame.bottomLeft, 1.0, -1.0),
      (frame.bottomRight, -1.0, -1.0),
    ]) {
      canvas.drawLine(point, point.translate(arm * dx, 0), corner);
      canvas.drawLine(point, point.translate(0, arm * dy), corner);
    }
  }

  @override
  bool shouldRepaint(_FramePainter old) =>
      old.frame != frame || old.color != color;
}
