import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../../data/collab/collab_session.dart';

const List<Color> _colors = [
  Color(0xFFC2410C),
  Color(0xFF047857),
  Color(0xFF1D4ED8),
  Color(0xFFA21CAF),
  Color(0xFFB91C1C),
  Color(0xFF0F766E),
  Color(0xFF6D28D9),
  Color(0xFFA16207),
];

/// The same color each person has on the web.
Color colorOfPeer(String id) {
  var hash = 0;
  for (final unit in id.codeUnits) {
    hash = (hash * 31 + unit) & 0xFFFFFFFF;
  }
  return _colors[hash % _colors.length];
}

/// Who moved a moment ago: their names show for a while, then only the carets.
class RecentlyMovedPeers extends ChangeNotifier {
  static const Duration _shows = Duration(milliseconds: 2500);

  final Map<String, String> _seen = {};
  final Map<String, Timer> _timers = {};

  bool isRecent(String id) => _timers.containsKey(id);

  void update(List<CollabPeer> peers) {
    for (final peer in peers) {
      if (peer.index == null) continue;
      final where = '${peer.index}:${peer.length}';
      if (_seen[peer.id] == where) continue;
      _seen[peer.id] = where;
      _timers[peer.id]?.cancel();
      _timers[peer.id] = Timer(_shows, () {
        _timers.remove(peer.id);
        notifyListeners();
      });
    }
  }

  @override
  void dispose() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    super.dispose();
  }
}

/// Everyone else's caret and selection, drawn over the editor.
class RemoteCursorsPainter extends CustomPainter {
  RemoteCursorsPainter({
    required Listenable repaint,
    required this.peers,
    required this.recent,
    required this.controller,
    required this.editor,
    required this.stack,
    required this.textDirection,
  }) : super(repaint: repaint);

  final ValueNotifier<List<CollabPeer>> peers;
  final RecentlyMovedPeers recent;
  final QuillController controller;
  final RenderEditor? Function() editor;
  final RenderBox? Function() stack;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    final render = editor();
    final host = stack();
    if (render == null || host == null || !render.attached || !render.hasSize) {
      return;
    }
    final textLength = controller.document.length;
    for (final peer in peers.value) {
      final index = peer.index;
      if (index == null || !peer.canEdit) continue;
      final start = index.clamp(0, textLength - 1);
      final end = (index + peer.length).clamp(start, textLength - 1);
      final color = colorOfPeer(peer.id);
      if (end > start) _paintSelection(canvas, render, host, start, end, color);
      _paintCaret(canvas, render, host, end, color, peer);
    }
  }

  void _paintSelection(
    Canvas canvas,
    RenderEditor render,
    RenderBox host,
    int start,
    int end,
    Color color,
  ) {
    final paint = Paint()..color = color.withValues(alpha: 0.22);
    var position = start;
    var guard = 0;
    while (position < end && guard++ < 200) {
      final line = render.getLineAtOffset(TextPosition(offset: position));
      final segmentEnd = line.end.clamp(position, end);
      if (segmentEnd <= position) break;
      final startRect = render.getLocalRectForCaret(
        TextPosition(offset: position),
      );
      final endRect = render.getLocalRectForCaret(
        TextPosition(offset: segmentEnd, affinity: TextAffinity.upstream),
      );
      final topLeft = host.globalToLocal(
        render.localToGlobal(startRect.topLeft),
      );
      final right = host
          .globalToLocal(
            render.localToGlobal(Offset(endRect.left, startRect.top)),
          )
          .dx;
      canvas.drawRect(
        Rect.fromLTWH(
          topLeft.dx,
          topLeft.dy,
          right - topLeft.dx,
          startRect.height,
        ),
        paint,
      );
      position = segmentEnd;
    }
  }

  void _paintCaret(
    Canvas canvas,
    RenderEditor render,
    RenderBox host,
    int at,
    Color color,
    CollabPeer peer,
  ) {
    final rect = render.getLocalRectForCaret(TextPosition(offset: at));
    // Inside a fold, or not laid out.
    if (rect.height <= 0) return;
    final topLeft = host.globalToLocal(render.localToGlobal(rect.topLeft));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(topLeft.dx - 1, topLeft.dy, 2, rect.height),
        const Radius.circular(1),
      ),
      Paint()..color = color,
    );
    if (!recent.isRecent(peer.id) || peer.name.isEmpty) return;
    final label = TextPainter(
      text: TextSpan(
        text: peer.name,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          height: 16 / 11,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: textDirection,
      maxLines: 1,
    )..layout(maxWidth: 160);
    final box = Rect.fromLTWH(
      topLeft.dx - 1,
      topLeft.dy - label.height,
      label.width + 10,
      label.height,
    );
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        box,
        topLeft: const Radius.circular(4),
        topRight: const Radius.circular(4),
        bottomRight: const Radius.circular(4),
      ),
      Paint()..color = color,
    );
    label.paint(canvas, box.topLeft + const Offset(5, 0));
    label.dispose();
  }

  @override
  bool shouldRepaint(covariant RemoteCursorsPainter old) => true;
}
