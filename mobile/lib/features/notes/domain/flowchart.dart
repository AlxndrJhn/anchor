import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:uuid/uuid.dart';

/// A flowchart placed in a note's text: a Delta embed,
/// `{"flowchart": "{\"nodes\":[…],\"edges\":[…]}"}`, as the web app writes
/// it (web/features/notes/flowcharts.ts). Nodes sit at their centres in the
/// chart's own units; their size follows from their shape and text, laid out
/// the same way as on the web, so a chart looks alike everywhere.
enum FlowShape {
  box,
  round,
  diamond;

  static FlowShape parse(Object? value) => switch (value) {
    'round' => round,
    'diamond' => diamond,
    _ => box,
  };
}

class FlowNode {
  const FlowNode({
    required this.id,
    required this.x,
    required this.y,
    this.text = '',
    this.shape = FlowShape.box,
  });

  final String id;
  final double x;
  final double y;
  final String text;
  final FlowShape shape;

  Offset get center => Offset(x, y);

  FlowNode copyWith({double? x, double? y, String? text, FlowShape? shape}) =>
      FlowNode(
        id: id,
        x: x ?? this.x,
        y: y ?? this.y,
        text: text ?? this.text,
        shape: shape ?? this.shape,
      );

  /// Width and height, from its shape and lines of text.
  Size get size {
    final lines = wrapFlowText(text, shape).length;
    return shape == FlowShape.diamond
        ? Size(170, math.max(84, 48 + lines * Flowchart.lineHeight))
        : Size(160, math.max(52, 22 + lines * Flowchart.lineHeight));
  }

  Rect get rect =>
      Rect.fromCenter(center: center, width: size.width, height: size.height);

  /// Where a line from the centre towards [toward] leaves the outline.
  Offset edgePoint(Offset toward) {
    final dx = toward.dx - x;
    final dy = toward.dy - y;
    if (dx == 0 && dy == 0) return center;
    final hw = size.width / 2;
    final hh = size.height / 2;
    final t = shape == FlowShape.diamond
        ? 1 / (dx.abs() / hw + dy.abs() / hh)
        : math.min(
            dx == 0 ? double.infinity : hw / dx.abs(),
            dy == 0 ? double.infinity : hh / dy.abs(),
          );
    return Offset(x + dx * t, y + dy * t);
  }

  /// The outline, in chart units.
  Path get outline {
    final r = rect;
    if (shape == FlowShape.diamond) {
      return Path()
        ..moveTo(x, r.top)
        ..lineTo(r.right, y)
        ..lineTo(x, r.bottom)
        ..lineTo(r.left, y)
        ..close();
    }
    final radius = shape == FlowShape.round ? r.height / 2 : 6.0;
    return Path()
      ..addRRect(RRect.fromRectAndRadius(r, Radius.circular(radius)));
  }

  /// Each line of text and the y it is centred on.
  List<(String, double)> get textLines {
    final lines = wrapFlowText(text, shape);
    final first = y - (lines.length - 1) * Flowchart.lineHeight / 2;
    return [
      for (var i = 0; i < lines.length; i++)
        (lines[i], first + i * Flowchart.lineHeight),
    ];
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'x': x.round(),
    'y': y.round(),
    'text': text,
    'shape': shape.name,
  };
}

class FlowEdge {
  const FlowEdge({
    required this.id,
    required this.from,
    required this.to,
    this.text,
  });

  final String id;
  final String from;
  final String to;
  final String? text;

  FlowEdge withText(String? value) => FlowEdge(
    id: id,
    from: from,
    to: to,
    text: value?.trim().isEmpty ?? true ? null : value!.trim(),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'from': from,
    'to': to,
    if (text?.trim().isNotEmpty ?? false) 'text': text!.trim(),
  };
}

class Flowchart {
  const Flowchart({this.nodes = const [], this.edges = const []});

  static const embedType = 'flowchart';
  static const lineHeight = 18.0;
  static const fontSize = 14.0;
  static const labelFontSize = 12.5;

  /// What positions snap to.
  static const grid = 10.0;

  static const _maxNodes = 200;
  static const _maxText = 200;

  final List<FlowNode> nodes;
  final List<FlowEdge> edges;

  static String newId() => const Uuid().v4().substring(0, 8);

  /// A start and a first step under it.
  factory Flowchart.starter() {
    final start = FlowNode(
      id: newId(),
      x: 0,
      y: 0,
      text: 'Start',
      shape: FlowShape.round,
    );
    final step = FlowNode(id: newId(), x: 0, y: 130, text: 'Step');
    return Flowchart(
      nodes: [start, step],
      edges: [FlowEdge(id: newId(), from: start.id, to: step.id)],
    );
  }

  /// Null when [data] isn't a flowchart's.
  static Flowchart? tryParse(Object? data) {
    if (data is! String) return null;
    Object? json;
    try {
      json = jsonDecode(data);
    } catch (_) {
      return null;
    }
    if (json is! Map || json['nodes'] is! List) return null;
    String text(Object? value) => value is String
        ? value
              .replaceAll(RegExp(r'\r\n?'), '\n')
              .substring(0, math.min(value.length, _maxText))
        : '';
    double coordinate(Object? value) =>
        value is num && value.isFinite ? value.toDouble().roundToDouble() : 0;
    final ids = <String>{};
    final nodes = <FlowNode>[];
    for (final raw in (json['nodes'] as List).take(_maxNodes)) {
      if (raw is! Map) continue;
      final id = raw['id'];
      if (id is! String || id.isEmpty || !ids.add(id)) continue;
      nodes.add(
        FlowNode(
          id: id,
          x: coordinate(raw['x']).clamp(-100000, 100000),
          y: coordinate(raw['y']).clamp(-100000, 100000),
          text: text(raw['text']),
          shape: FlowShape.parse(raw['shape']),
        ),
      );
    }
    final edgeIds = <String>{};
    final edges = <FlowEdge>[];
    final rawEdges = json['edges'];
    for (final raw in rawEdges is List ? rawEdges : const []) {
      if (raw is! Map) continue;
      final id = raw['id'];
      final from = raw['from'];
      final to = raw['to'];
      if (id is! String ||
          id.isEmpty ||
          !edgeIds.add(id) ||
          from is! String ||
          to is! String ||
          from == to ||
          !ids.contains(from) ||
          !ids.contains(to)) {
        continue;
      }
      final label = text(raw['text']).trim();
      edges.add(
        FlowEdge(
          id: id,
          from: from,
          to: to,
          text: label.isEmpty ? null : label,
        ),
      );
    }
    return Flowchart(nodes: nodes, edges: edges);
  }

  /// The embed's data, as the web app writes it.
  String encode() {
    final ids = nodes.map((n) => n.id).toSet();
    return jsonEncode({
      'nodes': [for (final node in nodes) node.toJson()],
      'edges': [
        for (final edge in edges)
          if (ids.contains(edge.from) && ids.contains(edge.to)) edge.toJson(),
      ],
    });
  }

  FlowNode? node(String id) {
    for (final node in nodes) {
      if (node.id == id) return node;
    }
    return null;
  }

  FlowEdge? edge(String id) {
    for (final edge in edges) {
      if (edge.id == id) return edge;
    }
    return null;
  }

  /// The arrow's two ends, on the outlines of the nodes it joins.
  (Offset, Offset)? ends(FlowEdge edge) {
    final from = node(edge.from);
    final to = node(edge.to);
    if (from == null || to == null) return null;
    return (from.edgePoint(to.center), to.edgePoint(from.center));
  }

  FlowNode? nodeAt(Offset point) {
    for (final node in nodes.reversed) {
      if (node.rect.contains(point)) return node;
    }
    return null;
  }

  /// The arrow nearest [point] within [tolerance].
  FlowEdge? edgeAt(Offset point, double tolerance) {
    FlowEdge? best;
    var bestDistance = tolerance;
    for (final edge in edges) {
      final line = ends(edge);
      if (line == null) continue;
      final (start, end) = line;
      final d = end - start;
      final length = d.distanceSquared;
      final t = length == 0
          ? 0.0
          : (((point - start).dx * d.dx + (point - start).dy * d.dy) / length)
                .clamp(0.0, 1.0);
      final distance = (point - (start + d * t)).distance;
      if (distance <= bestDistance) {
        best = edge;
        bestDistance = distance;
      }
    }
    return best;
  }

  /// The box holding the whole chart, or null for an empty one.
  Rect? get bounds {
    if (nodes.isEmpty) return null;
    return nodes.map((n) => n.rect).reduce((a, b) => a.expandToInclude(b));
  }

  /// Where a new node goes beside [from], towards [side]: clear of it by a
  /// gap, whatever the two shapes' sizes.
  static Offset spotBeside(
    FlowNode from,
    Offset side, [
    FlowShape shape = FlowShape.box,
  ]) {
    final own = from.size;
    final next = FlowNode(id: '', x: 0, y: 0, shape: shape).size;
    final gap = side.dx != 0 ? 70.0 : 56.0;
    return Offset(
      from.x + side.dx * (own.width / 2 + gap + next.width / 2),
      from.y + side.dy * (own.height / 2 + gap + next.height / 2),
    );
  }

  /// The words in the chart, for search.
  String get words =>
      [...nodes.map((n) => n.text), ...edges.map((e) => e.text ?? '')]
          .map((s) => s.replaceAll(RegExp(r'\s+'), ' ').trim())
          .where((s) => s.isNotEmpty)
          .join(' ');

  /// A short name for screen readers: its first node's text.
  String get label {
    for (final node in nodes) {
      final text = node.text.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }
}

/// A node's text broken into the lines it's drawn on: at words, and long
/// words where they must. As web/features/notes/flowcharts.ts does it.
List<String> wrapFlowText(String value, FlowShape shape) {
  final width = shape == FlowShape.diamond ? 14 : 18;
  final lines = <String>[];
  for (final paragraph in value.split('\n')) {
    var line = '';
    for (final word
        in paragraph.split(RegExp(r'\s+')).where((w) => w.isNotEmpty)) {
      var rest = word;
      while (rest.isNotEmpty) {
        final room = line.isEmpty ? width : width - line.length - 1;
        if (rest.length <= room) {
          line = line.isEmpty ? rest : '$line $rest';
          rest = '';
        } else if (line.isNotEmpty) {
          lines.add(line);
          line = '';
        } else {
          lines.add(rest.substring(0, width));
          rest = rest.substring(width);
        }
      }
    }
    lines.add(line);
  }
  while (lines.length > 1 && lines.last.isEmpty) {
    lines.removeLast();
  }
  return lines;
}

/// An arrow's label broken into lines, like a box's text.
List<String> wrapFlowLabel(String value) => wrapFlowText(value, FlowShape.box);

/// The words in the flowcharts of a note's stored [content], for search.
String flowchartWordsOf(String? content) {
  if (content == null || !content.contains(Flowchart.embedType)) return '';
  Object? json;
  try {
    json = jsonDecode(content);
  } catch (_) {
    return '';
  }
  final ops = json is Map ? json['ops'] : null;
  if (ops is! List) return '';
  return [
    for (final op in ops)
      if (op is Map && op['insert'] is Map)
        Flowchart.tryParse((op['insert'] as Map)[Flowchart.embedType])?.words,
  ].whereType<String>().where((w) => w.isNotEmpty).join('\n');
}

/// The first flowchart in a note's stored [content], for its card.
Flowchart? firstFlowchartOf(String? content) {
  if (content == null || !content.contains(Flowchart.embedType)) return null;
  Object? json;
  try {
    json = jsonDecode(content);
  } catch (_) {
    return null;
  }
  final ops = json is Map ? json['ops'] : null;
  if (ops is! List) return null;
  for (final op in ops) {
    if (op is! Map || op['insert'] is! Map) continue;
    final chart = Flowchart.tryParse(
      (op['insert'] as Map)[Flowchart.embedType],
    );
    if (chart != null && chart.nodes.isNotEmpty) return chart;
  }
  return null;
}
