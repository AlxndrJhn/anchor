import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/// How long a card takes to burn away.
const destructionDuration = Duration(milliseconds: 1100);

/// The cards on screen that can be destroyed, by note id.
final _cards = <String, GlobalKey>{};

/// Marks [child] as the card of note [id], so deleting the note can burn
/// it away where it stands; see [destroyNoteCards].
class Destructible extends StatefulWidget {
  const Destructible({super.key, required this.id, required this.child});

  final String id;
  final Widget child;

  @override
  State<Destructible> createState() => _DestructibleState();
}

class _DestructibleState extends State<Destructible> {
  final _key = GlobalKey();

  @override
  void initState() {
    super.initState();
    _cards[widget.id] = _key;
  }

  @override
  void didUpdateWidget(Destructible oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      if (_cards[oldWidget.id] == _key) _cards.remove(oldWidget.id);
      _cards[widget.id] = _key;
    }
  }

  @override
  void dispose() {
    // A card dragged in hand is a second copy: only forget our own.
    if (_cards[widget.id] == _key) _cards.remove(widget.id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      RepaintBoundary(key: _key, child: widget.child);
}

/// Burns away the cards of notes [ids] that are on screen, as Balatro
/// destroys a card: a jolt, then it dissolves in glowing pixels and
/// sparks. Returns once they're captured, so the notes can go at once; the
/// effect plays over whatever takes their place.
void destroyNoteCards(BuildContext context, Iterable<String> ids) {
  for (final id in ids) {
    final key = _cards[id];
    if (key != null) destroyView(context, key);
  }
}

/// Burns away what the [RepaintBoundary] with [key] shows, the same way;
/// e.g. a note's page as it closes.
void destroyView(BuildContext context, GlobalKey key) {
  if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return;
  final boundary = key.currentContext?.findRenderObject();
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (boundary is! RenderRepaintBoundary ||
      !boundary.attached ||
      !boundary.hasSize ||
      overlay == null) {
    return;
  }
  final overlayBox = overlay.context.findRenderObject() as RenderBox?;
  if (overlayBox == null) return;
  final pixelRatio = math.min(MediaQuery.devicePixelRatioOf(context), 2.0);
  final ui.Image image;
  try {
    image = boundary.toImageSync(pixelRatio: pixelRatio);
  } catch (_) {
    return;
  }
  final topLeft = overlayBox.globalToLocal(boundary.localToGlobal(Offset.zero));
  final rect = topLeft & boundary.size;
  HapticFeedback.heavyImpact();

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _Destruction(
      image: image,
      rect: rect,
      onDone: () {
        entry.remove();
        image.dispose();
      },
    ),
  );
  overlay.insert(entry);
}

class _Destruction extends StatefulWidget {
  const _Destruction({
    required this.image,
    required this.rect,
    required this.onDone,
  });

  final ui.Image image;
  final Rect rect;
  final VoidCallback onDone;

  @override
  State<_Destruction> createState() => _DestructionState();
}

class _DestructionState extends State<_Destruction>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: destructionDuration)
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed) widget.onDone();
        })
        ..forward();
  late final BurnPattern _pattern = BurnPattern.forSize(
    widget.rect.size,
    seed: widget.rect.hashCode,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Sparks fly a little beyond the card.
    final rect = widget.rect.inflate(BurnPainter.margin);
    return Positioned.fromRect(
      rect: rect,
      child: IgnorePointer(
        child: CustomPaint(
          painter: BurnPainter(
            image: widget.image,
            pattern: _pattern,
            progress: _controller,
          ),
        ),
      ),
    );
  }
}

/// Where a card burns first: one threshold per block, from 0 (first) to 1
/// (last), in smooth patches like Balatro's dissolve.
class BurnPattern {
  BurnPattern(this.columns, this.rows, this.cell, this.thresholds);

  factory BurnPattern.forSize(Size size, {int seed = 0}) {
    // Small cards in fine pixels; a whole page in coarser ones.
    final cell = math
        .sqrt(size.width * size.height / 1800)
        .clamp(5.0, 14.0)
        .toDouble();
    final columns = math.max(1, (size.width / cell).ceil());
    final rows = math.max(1, (size.height / cell).ceil());
    final random = math.Random(seed);
    // Value noise: a coarse lattice, smoothly blended, and some grain.
    // Patches about a quarter of the card across, so it burns in holes that
    // spread rather than in specks.
    final blob =
        (math.min(size.width, size.height) / 4).clamp(24.0, 90.0) / cell;
    final lw = (columns / blob).ceil() + 2;
    final lh = (rows / blob).ceil() + 2;
    final lattice = List.generate(lw * lh, (_) => random.nextDouble());
    double at(int x, int y) => lattice[y * lw + x];
    double smooth(double t) => t * t * (3 - 2 * t);
    final raw = List<double>.filled(columns * rows, 0);
    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < columns; x++) {
        final fx = x / blob, fy = y / blob;
        final ix = fx.floor(), iy = fy.floor();
        final tx = smooth(fx - ix), ty = smooth(fy - iy);
        final top = at(ix, iy) + (at(ix + 1, iy) - at(ix, iy)) * tx;
        final bottom =
            at(ix, iy + 1) + (at(ix + 1, iy + 1) - at(ix, iy + 1)) * tx;
        raw[y * columns + x] =
            top + (bottom - top) * ty + random.nextDouble() * 0.08;
      }
    }
    final low = raw.reduce(math.min), high = raw.reduce(math.max);
    final span = high - low == 0 ? 1.0 : high - low;
    return BurnPattern(columns, rows, cell, [
      for (final v in raw) (v - low) / span,
    ]);
  }

  final int columns;
  final int rows;
  final double cell;
  final List<double> thresholds;
}

/// What a block of the card is at one moment of the burn.
enum BlockState { whole, burning, gone }

/// The jolt takes the start of the effect; the burn the rest.
const _joltEnd = 0.14;

/// How far the glowing edge reaches into the card, in thresholds.
const _edge = 0.1;

/// How far the burn has gone at [t] (0 to 1 of the effect), from 0 to just
/// past 1, so that the last blocks burn too.
double burnFront(double t) {
  if (t <= _joltEnd) return 0;
  final d = (t - _joltEnd) / (1 - _joltEnd);
  return Curves.easeIn.transform(d) * (1 + _edge * 1.2);
}

BlockState blockStateAt(double threshold, double front) {
  if (threshold < front - _edge) return BlockState.gone;
  if (threshold < front) return BlockState.burning;
  return BlockState.whole;
}

class BurnPainter extends CustomPainter {
  BurnPainter({
    required this.image,
    required this.pattern,
    required this.progress,
  }) : super(repaint: progress);

  /// Room around the card for the sparks.
  static const margin = 40.0;

  final ui.Image image;
  final BurnPattern pattern;
  final Animation<double> progress;

  static const _glow = [
    Color(0xFFFFF6C8),
    Color(0xFFFFC94A),
    Color(0xFFFF7A2E),
    Color(0xFFE2362B),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value;
    final card = Rect.fromLTWH(
      margin,
      margin,
      size.width - margin * 2,
      size.height - margin * 2,
    );
    final front = burnFront(t);

    canvas.save();
    // The jolt: a shake that settles, a little bigger, a flash.
    final jolt = (1 - (t / _joltEnd)).clamp(0.0, 1.0);
    final grow = 1 + 0.06 * math.sin(math.min(1.0, t / _joltEnd) * math.pi);
    final angle = math.sin(t * 90) * 0.05 * jolt;
    final shake = Offset(math.sin(t * 130) * 4 * jolt, 0);
    canvas.translate(card.center.dx + shake.dx, card.center.dy + shake.dy);
    canvas.rotate(angle);
    canvas.scale(grow);
    canvas.translate(-card.center.dx, -card.center.dy);

    final cell = pattern.cell;
    final scaleX = image.width / card.width;
    final scaleY = image.height / card.height;
    final transforms = <RSTransform>[];
    final sources = <Rect>[];
    final burning = List.generate(_glow.length, (_) => Path());
    final sparks = List.generate(_glow.length, (_) => Path());

    for (var y = 0; y < pattern.rows; y++) {
      for (var x = 0; x < pattern.columns; x++) {
        final threshold = pattern.thresholds[y * pattern.columns + x];
        final left = card.left + x * cell;
        final top = card.top + y * cell;
        final w = math.min(cell, card.right - left);
        final h = math.min(cell, card.bottom - top);
        switch (blockStateAt(threshold, front)) {
          case BlockState.whole:
            transforms.add(
              RSTransform.fromComponents(
                rotation: 0,
                scale: 1 / scaleX,
                anchorX: 0,
                anchorY: 0,
                translateX: left,
                translateY: top,
              ),
            );
            sources.add(
              Rect.fromLTWH(
                (x * cell) * scaleX,
                (y * cell) * scaleY,
                w * scaleX,
                h * scaleY,
              ),
            );
          case BlockState.burning:
            // Hottest at the very edge, cooling into the card.
            final heat = ((front - threshold) / _edge).clamp(0.0, 0.999);
            final band = (heat * _glow.length).floor();
            burning[band].addRect(Rect.fromLTWH(left, top, w, h));
          case BlockState.gone:
            // Some burnt blocks fly off as sparks, up and away.
            if ((x * 7 + y * 13) % 5 != 0) break;
            final age = (front - _edge - threshold) * 2.2;
            if (age > 1) break;
            final drift = math.sin(x * 12.9898 + y * 78.233) * 22;
            final size = cell * 0.6 * (1 - age);
            final band = (age * _glow.length).floor().clamp(
              0,
              _glow.length - 1,
            );
            sparks[band].addRect(
              Rect.fromCenter(
                center: Offset(
                  left + w / 2 + drift * age,
                  top + h / 2 - 46 * age,
                ),
                width: size,
                height: size,
              ),
            );
        }
      }
    }

    // In a layer, so the flash lights only the card, not its clear corners.
    canvas.saveLayer(card.inflate(cell), Paint());
    if (transforms.isNotEmpty) {
      canvas.drawAtlas(
        image,
        transforms,
        sources,
        null,
        null,
        null,
        Paint()..filterQuality = FilterQuality.low,
      );
    }
    // The flash, fading as the card settles.
    if (jolt > 0) {
      canvas.drawRect(
        card,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.4 * jolt)
          ..blendMode = BlendMode.srcATop,
      );
    }
    canvas.restore();
    for (var i = 0; i < _glow.length; i++) {
      canvas.drawPath(burning[i], Paint()..color = _glow[i]);
      canvas.drawPath(
        sparks[i],
        Paint()..color = _glow[i].withValues(alpha: 0.9),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(BurnPainter oldDelegate) =>
      oldDelegate.image != image ||
      oldDelegate.pattern != pattern ||
      oldDelegate.progress != progress;
}
