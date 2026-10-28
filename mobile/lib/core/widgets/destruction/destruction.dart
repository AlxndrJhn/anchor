import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../motion/haptics.dart';
import '../../motion/springs.dart';

import 'strike.dart';

/// How long a card takes to burn away.
const destructionDuration = Duration(milliseconds: 1100);

/// How long the last sparks keep flying, fading out, once the card is gone.
const burnTailDuration = Duration(milliseconds: 500);

/// The end of the sparks' fade, in the effect's time (1 = the card is gone).
final double burnTailEnd =
    1 + burnTailDuration.inMicroseconds / destructionDuration.inMicroseconds;

/// The cards on screen that can be burnt, by note id.
final _cards = <String, DestructibleState>{};

/// Something that can burn away in place, as Balatro destroys a card: a
/// jolt, then it dissolves in glowing pixels and sparks. It keeps its place
/// meanwhile, so nothing moves into it; afterwards it stays invisible, for
/// its owner to remove. Given an [id], it's the card of that note; see
/// [burnNoteCards].
class Destructible extends StatefulWidget {
  const Destructible({super.key, this.id, required this.child});

  final String? id;
  final Widget child;

  @override
  State<Destructible> createState() => DestructibleState();
}

class DestructibleState extends State<Destructible>
    with SingleTickerProviderStateMixin {
  final _boundary = GlobalKey();
  AnimationController? _controller;
  ui.Image? _image;
  BurnPattern? _pattern;

  @override
  void initState() {
    super.initState();
    _register(widget.id);
  }

  @override
  void didUpdateWidget(Destructible oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      _forget(oldWidget.id);
      _register(widget.id);
    }
  }

  void _register(String? id) {
    if (id != null) _cards[id] = this;
  }

  // A card dragged in hand is a second copy: only forget our own.
  void _forget(String? id) {
    if (id != null && _cards[id] == this) _cards.remove(id);
  }

  @override
  void dispose() {
    _forget(widget.id);
    _controller?.dispose();
    _image?.dispose();
    super.dispose();
  }

  /// Burns it away; completes when it's gone. Straight away with
  /// animations turned off.
  Future<void> burn() async {
    if (_controller != null) return;
    if (context.isMotionReduced) return;
    final boundary = _boundary.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary ||
        !boundary.attached ||
        !boundary.hasSize) {
      return;
    }
    final ui.Image image;
    try {
      image = boundary.toImageSync(
        pixelRatio: math.min(MediaQuery.devicePixelRatioOf(context), 2.0),
      );
    } catch (_) {
      return;
    }
    Haptics.heavy();
    final controller = AnimationController(
      vsync: this,
      duration: destructionDuration,
    );
    setState(() {
      _image = image;
      _pattern = BurnPattern.forSize(boundary.size, seed: widget.id.hashCode);
      _controller = controller;
    });
    try {
      await controller.forward().orCancel;
    } on TickerCanceled {
      // Gone before it finished burning.
      return;
    }
    if (mounted) _leaveSparks();
  }

  /// The card is about to go: its last sparks fly on above everything,
  /// fading out, rather than vanishing with it.
  void _leaveSparks() {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    final box = context.findRenderObject();
    final overlayBox = overlay?.context.findRenderObject();
    if (overlay == null ||
        box is! RenderBox ||
        overlayBox is! RenderBox ||
        !box.attached ||
        !box.hasSize) {
      return;
    }
    final origin = box.localToGlobal(Offset.zero, ancestor: overlayBox);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Positioned(
        left: origin.dx - BurnPainter.margin,
        top: origin.dy - BurnPainter.margin,
        width: box.size.width + BurnPainter.margin * 2,
        height: box.size.height + BurnPainter.margin * 2,
        child: _BurnTail(
          image: _image!.clone(),
          pattern: _pattern!,
          onDone: () => entry.remove(),
        ),
      ),
    );
    overlay.insert(entry);
  }

  /// Shows it again, as it was; for when the delete failed.
  void restore() {
    final controller = _controller;
    if (controller == null) return;
    controller.dispose();
    _image?.dispose();
    setState(() {
      _controller = null;
      _image = null;
      _pattern = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final child = RepaintBoundary(key: _boundary, child: widget.child);
    final controller = _controller;
    if (controller == null) return child;
    // Burning: the card keeps its place, drawn by the burn instead.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IgnorePointer(child: Opacity(opacity: 0, child: child)),
        Positioned(
          left: -BurnPainter.margin,
          top: -BurnPainter.margin,
          right: -BurnPainter.margin,
          bottom: -BurnPainter.margin,
          child: IgnorePointer(
            child: CustomPaint(
              painter: BurnPainter(
                image: _image!,
                pattern: _pattern!,
                progress: controller,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The sparks a burnt card leaves, flying on and fading out.
class _BurnTail extends StatefulWidget {
  const _BurnTail({
    required this.image,
    required this.pattern,
    required this.onDone,
  });

  final ui.Image image;
  final BurnPattern pattern;
  final VoidCallback onDone;

  @override
  State<_BurnTail> createState() => _BurnTailState();
}

class _BurnTailState extends State<_BurnTail>
    with SingleTickerProviderStateMixin {
  late final _controller =
      AnimationController(
          vsync: this,
          duration: burnTailDuration,
          lowerBound: 1,
          upperBound: burnTailEnd,
        )
        ..forward(from: 1).whenComplete(() {
          if (mounted) widget.onDone();
        });

  @override
  void dispose() {
    _controller.dispose();
    widget.image.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: CustomPaint(
      painter: BurnPainter(
        image: widget.image,
        pattern: widget.pattern,
        progress: _controller,
      ),
    ),
  );
}

/// Shows the cards of notes [ids] again, for when the delete failed.
void restoreNoteCards(Iterable<String> ids) {
  for (final id in ids) {
    _cards[id]?.restore();
  }
}

/// Burns away, in place, the cards of notes [ids] that are on screen;
/// completes when they're gone, for the notes to be deleted then. The cards
/// that move into their places strike there; see [StrikeImpact].
Future<void> burnNoteCards(Iterable<String> ids) async {
  await Future.wait([
    for (final id in ids)
      if (_cards[id] case final card?) card.burn(),
  ]);
  armCardStrike();
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
/// past 1, so that the last blocks burn too. Past 1 (the sparks' tail) it
/// keeps going at about its final pace, so the sparks keep flying.
double burnFront(double t) {
  if (t <= _joltEnd) return 0;
  if (t > 1) return burnFront(1) + (t - 1) * 2.2;
  final d = (t - _joltEnd) / (1 - _joltEnd);
  return Curves.easeIn.transform(d) * (1 + _edge * 1.2);
}

/// How visible the sparks are at [t]: fully during the burn, fading to
/// nothing over the tail.
double sparkOpacity(double t) =>
    t <= 1 ? 1 : (1 - (t - 1) / (burnTailEnd - 1)).clamp(0.0, 1.0);

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
    final opacity = sparkOpacity(t);
    for (var i = 0; i < _glow.length; i++) {
      canvas.drawPath(
        burning[i],
        Paint()..color = _glow[i].withValues(alpha: opacity),
      );
      canvas.drawPath(
        sparks[i],
        Paint()..color = _glow[i].withValues(alpha: 0.9 * opacity),
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
