import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../../../../core/theme/context_extensions.dart';
import '../../../../l10n/l10n.dart';
import '../../domain/flowchart.dart';
import 'editor_palette.dart';
import 'flowchart_editor_screen.dart';
import 'flowchart_painter.dart';

/// A flowchart's colours in a note drawn with [palette].
FlowchartColors flowchartColorsOf(
  BuildContext context,
  EditorPalette palette,
) => FlowchartColors(
  ink: context.anchor.appText,
  fill: palette.surface,
  ground: palette.background,
  accent: context.anchor.accentStrong,
);

/// Draws the flowcharts in a note's text ([Flowchart]); a tap opens one to
/// change it, where the note can be changed.
class FlowchartEmbedBuilder extends EmbedBuilder {
  const FlowchartEmbedBuilder({required this.palette});

  final EditorPalette Function() palette;

  @override
  String get key => Flowchart.embedType;

  @override
  bool get expanded => true;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final chart = Flowchart.tryParse(embedContext.node.value.data);
    if (chart == null) return const SizedBox.shrink();
    return _FlowchartEmbed(
      chart: chart,
      colors: flowchartColorsOf(context, palette()),
      place: _Place(embedContext.controller, embedContext.node),
      readOnly: embedContext.readOnly,
    );
  }
}

class _FlowchartEmbed extends StatelessWidget {
  const _FlowchartEmbed({
    required this.chart,
    required this.colors,
    required this.place,
    required this.readOnly,
  });

  final Flowchart chart;
  final FlowchartColors colors;
  final _Place place;
  final bool readOnly;

  Future<void> _open(BuildContext context) async {
    final result = await FlowchartEditorScreen.open(
      context,
      chart: chart,
      colors: colors,
    );
    switch (result) {
      case FlowchartSaved(:final chart):
        place.replace(chart);
      case FlowchartRemoved():
        place.remove();
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final label = chart.label;
    return Semantics(
      container: true,
      image: readOnly,
      button: !readOnly,
      label: label.isEmpty ? l10n.flowchart : l10n.flowchartLabel(label),
      hint: readOnly ? null : l10n.flowchartOpenHint,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: readOnly ? null : () => _open(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: FlowchartView(chart: chart, colors: colors),
        ),
      ),
    );
  }
}

/// A chart's spot in the text, to change it there.
class _Place {
  const _Place(this.controller, this.node);

  final QuillController controller;
  final Embed node;

  /// Null once the chart has left the text (deleted, undone, or the note
  /// reloaded).
  int? get offset {
    if (node.parent == null) return null;
    final at = node.documentOffset;
    final there = controller.document.querySegmentLeafNode(at).leaf;
    return identical(there, node) ? at : null;
  }

  void replace(Flowchart chart) {
    final at = offset;
    if (at == null) return;
    _quietly(
      () => controller.replaceText(
        at,
        1,
        BlockEmbed(Flowchart.embedType, chart.encode()),
        null,
      ),
    );
  }

  void remove() {
    final at = offset;
    if (at == null) return;
    // The chart's line goes with it.
    final hasLine =
        at + 1 < controller.document.length &&
        controller.document.getPlainText(at + 1, 1) == '\n';
    _quietly(
      () => controller.replaceText(
        at,
        hasLine ? 2 : 1,
        '',
        TextSelection.collapsed(offset: at),
      ),
    );
  }

  /// Changes the text without the keyboard popping up.
  void _quietly(VoidCallback change) {
    controller.skipRequestKeyboard = true;
    change();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => controller.skipRequestKeyboard = false,
    );
  }
}
