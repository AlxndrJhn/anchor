import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_typography.dart';
import '../../domain/flowchart.dart';

/// The colours a flowchart is drawn in, taken from the note it sits in.
class FlowchartColors {
  const FlowchartColors({
    required this.ink,
    required this.fill,
    required this.ground,
    required this.accent,
  });

  /// Text.
  final Color ink;

  /// Inside a step.
  final Color fill;

  /// The note behind: under arrow labels.
  final Color ground;

  /// Picked things, and the tint of decisions and starts.
  final Color accent;

  Color get line => ink.withValues(alpha: 0.62);

  Color fillOf(FlowShape shape) => switch (shape) {
    FlowShape.box => fill,
    FlowShape.diamond => Color.alphaBlend(
      accent.withValues(alpha: 0.12),
      ground,
    ),
    FlowShape.round => Color.alphaBlend(accent.withValues(alpha: 0.22), ground),
  };
}

/// What the editor marks on the chart; nothing when just showing it.
class FlowchartMarks {
  const FlowchartMarks({
    this.pickedNode,
    this.pickedEdge,
    this.target,
    this.link,
    this.handles = const [],
  });

  final String? pickedNode;
  final String? pickedEdge;

  /// The node an arrow being drawn would join.
  final String? target;

  /// An arrow being drawn: from a node's centre to the finger.
  final (Offset, Offset)? link;

  /// The dots round the picked node, in chart units.
  final List<Offset> handles;
}

/// Draws [chart] with its own units mapped by [scale] and [offset]: a point
/// p of the chart lands at p * scale + offset.
class FlowchartPainter extends CustomPainter {
  FlowchartPainter({
    required this.chart,
    required this.colors,
    required this.textDirection,
    this.scale = 1,
    this.offset = Offset.zero,
    this.marks = const FlowchartMarks(),
    this.fontFamily,
  });

  final Flowchart chart;
  final FlowchartColors colors;
  final TextDirection textDirection;
  final double scale;
  final Offset offset;
  final FlowchartMarks marks;
  final String? fontFamily;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.scale(scale);
    final line = Paint()
      ..color = colors.line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final picked = Paint()
      ..color = colors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    for (final edge in chart.edges) {
      final ends = chart.ends(edge);
      if (ends == null) continue;
      final isPicked = edge.id == marks.pickedEdge;
      _arrow(canvas, ends.$1, ends.$2, isPicked ? picked : line);
      final text = edge.text;
      if (text != null && text.isNotEmpty) {
        _label(canvas, text, (ends.$1 + ends.$2) / 2);
      }
    }
    if (marks.link case (final from, final to)) {
      _arrow(canvas, from, to, picked, dashed: true);
    }
    for (final node in chart.nodes) {
      final outline = node.outline;
      canvas.drawPath(outline, Paint()..color = colors.fillOf(node.shape));
      final isPicked = node.id == marks.pickedNode;
      final isTarget = node.id == marks.target;
      canvas.drawPath(outline, isPicked || isTarget ? picked : line);
      for (final (text, y) in node.textLines) {
        _text(
          canvas,
          text,
          Offset(node.x, y),
          Flowchart.fontSize,
          FontWeight.w500,
        );
      }
    }
    for (final handle in marks.handles) {
      canvas.drawCircle(handle, 9, Paint()..color = colors.accent);
      canvas.drawCircle(
        handle,
        9,
        Paint()
          ..color = colors.ground
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      final plus = Paint()
        ..color = colors.ground
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        handle - const Offset(4, 0),
        handle + const Offset(4, 0),
        plus,
      );
      canvas.drawLine(
        handle - const Offset(0, 4),
        handle + const Offset(0, 4),
        plus,
      );
    }
    canvas.restore();
  }

  void _arrow(
    Canvas canvas,
    Offset from,
    Offset to,
    Paint paint, {
    bool dashed = false,
  }) {
    final d = to - from;
    final length = d.distance;
    if (length < 1) return;
    final unit = d / length;
    // The line stops where the head starts, so it doesn't poke through.
    final shaft = to - unit * 8;
    if (dashed) {
      for (var at = 0.0; at < length - 8; at += 10) {
        canvas.drawLine(
          from + unit * at,
          from + unit * math.min(at + 6, length - 8),
          paint,
        );
      }
    } else {
      canvas.drawLine(from, shaft, paint);
    }
    final normal = Offset(-unit.dy, unit.dx);
    final head = Path()
      ..moveTo(to.dx, to.dy)
      ..lineTo((shaft + normal * 4.5).dx, (shaft + normal * 4.5).dy)
      ..lineTo((shaft - normal * 4.5).dx, (shaft - normal * 4.5).dy)
      ..close();
    canvas.drawPath(head, Paint()..color = paint.color);
  }

  void _label(Canvas canvas, String value, Offset at) {
    final lines = wrapFlowLabel(value);
    final painters = [
      for (final line in lines)
        _layout(line, Flowchart.labelFontSize, FontWeight.w400),
    ];
    final width = painters.map((p) => p.width).fold(0.0, math.max) + 12;
    final height = lines.length * Flowchart.lineHeight + 4;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: at, width: width, height: height),
        const Radius.circular(4),
      ),
      Paint()..color = colors.ground,
    );
    final first = at.dy - (lines.length - 1) * Flowchart.lineHeight / 2;
    for (var i = 0; i < painters.length; i++) {
      final p = painters[i];
      p.paint(
        canvas,
        Offset(
          at.dx - p.width / 2,
          first + i * Flowchart.lineHeight - p.height / 2,
        ),
      );
    }
  }

  void _text(
    Canvas canvas,
    String value,
    Offset center,
    double fontSize,
    FontWeight weight,
  ) {
    if (value.isEmpty) return;
    final p = _layout(value, fontSize, weight);
    p.paint(canvas, center - Offset(p.width / 2, p.height / 2));
  }

  TextPainter _layout(String value, double fontSize, FontWeight weight) =>
      TextPainter(
        text: TextSpan(
          text: value,
          style: TextStyle(
            color: colors.ink,
            fontSize: fontSize,
            fontWeight: weight,
            fontFamily: fontFamily,
            height: 1,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: textDirection,
        maxLines: 1,
      )..layout();

  @override
  bool shouldRepaint(FlowchartPainter old) =>
      old.chart != chart ||
      old.colors != colors ||
      old.scale != scale ||
      old.offset != offset ||
      old.marks != marks ||
      old.fontFamily != fontFamily;
}

/// A whole chart, drawn at its own size, shrunk to fit the width it has.
class FlowchartView extends StatelessWidget {
  const FlowchartView({
    super.key,
    required this.chart,
    required this.colors,
    this.maxHeight,
  });

  static const padding = 12.0;

  final Flowchart chart;
  final FlowchartColors colors;
  final double? maxHeight;

  @override
  Widget build(BuildContext context) {
    final bounds = (chart.bounds ?? const Rect.fromLTWH(0, 0, 160, 52)).inflate(
      padding,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        var scale = math.min(1.0, constraints.maxWidth / bounds.width);
        if (maxHeight case final max?) {
          scale = math.min(scale, max / bounds.height);
        }
        final size = Size(bounds.width * scale, bounds.height * scale);
        return Center(
          child: CustomPaint(
            size: size,
            painter: FlowchartPainter(
              chart: chart,
              colors: colors,
              textDirection: Directionality.of(context),
              scale: scale,
              offset: -bounds.topLeft * scale,
              fontFamily: AppTypography.sans,
            ),
          ),
        );
      },
    );
  }
}
