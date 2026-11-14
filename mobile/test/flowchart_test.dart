import 'dart:convert';

import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/features/notes/domain/flowchart.dart';
import 'package:anchor/features/notes/presentation/editor/flowchart_editor_screen.dart';
import 'package:anchor/features/notes/presentation/editor/flowchart_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The chart the web app's tests use (web/features/notes/flowcharts.test.ts),
/// as the web writes it.
const _web =
    '{"nodes":[{"id":"a","x":0,"y":0,"text":"Start","shape":"round"},'
    '{"id":"b","x":0,"y":200,"text":"Is it <ok>?","shape":"diamond"}],'
    '"edges":[{"id":"e","from":"a","to":"b","text":"next"}]}';

const _colors = FlowchartColors(
  ink: Color(0xFF202124),
  fill: Color(0xFFF0F4F7),
  ground: Color(0xFFFFFFFF),
  accent: Color(0xFF13687A),
);

void main() {
  group('Flowchart', () {
    test('reads what the web writes, and writes it back the same', () {
      final chart = Flowchart.tryParse(_web)!;
      expect(chart.nodes.map((n) => n.text), ['Start', 'Is it <ok>?']);
      expect(chart.nodes.map((n) => n.shape), [
        FlowShape.round,
        FlowShape.diamond,
      ]);
      expect(chart.edges.single.text, 'next');
      expect(jsonDecode(chart.encode()), jsonDecode(_web));
    });

    test('drops what it cannot draw', () {
      final chart = Flowchart.tryParse(
        jsonEncode({
          'nodes': [
            {'id': 'a', 'x': 1.6, 'y': 'x', 'text': 5, 'shape': 'star'},
            {'id': 'a', 'x': 0, 'y': 0},
            {'x': 0, 'y': 0},
          ],
          'edges': [
            {'id': 'e1', 'from': 'a', 'to': 'gone'},
            {'id': 'e2', 'from': 'a', 'to': 'a'},
          ],
        }),
      )!;
      expect(chart.nodes.single.toJson(), {
        'id': 'a',
        'x': 2,
        'y': 0,
        'text': '',
        'shape': 'box',
      });
      expect(chart.edges, isEmpty);
      expect(Flowchart.tryParse('not json'), isNull);
      expect(Flowchart.tryParse('{"edges":[]}'), isNull);
    });

    test('wraps text as the web does', () {
      expect(wrapFlowText('Check the order and send it', FlowShape.box), [
        'Check the order',
        'and send it',
      ]);
      expect(wrapFlowText('a\nb', FlowShape.box), ['a', 'b']);
      expect(wrapFlowText('x' * 20, FlowShape.box), ['x' * 18, 'xx']);
      expect(wrapFlowText('', FlowShape.box), ['']);
    });

    test('sizes, outlines and arrow ends match the web', () {
      final chart = Flowchart.tryParse(_web)!;
      final (start, end) = chart.ends(chart.edges.single)!;
      expect(start, const Offset(0, 26));
      expect(end, const Offset(0, 200 - 42));
      expect(chart.bounds!.left, -85);
      expect(chart.nodeAt(const Offset(10, 5))?.id, 'a');
      expect(chart.nodeAt(const Offset(500, 0)), isNull);
      expect(chart.edgeAt(const Offset(4, 100), 9)?.id, 'e');
      expect(chart.edgeAt(const Offset(40, 100), 9), isNull);
    });

    test('finds the words in a note\'s charts', () {
      final content = jsonEncode({
        'ops': [
          {'insert': 'Plan\n'},
          {
            'insert': {'flowchart': _web},
          },
          {'insert': '\n'},
        ],
      });
      expect(flowchartWordsOf(content), 'Start Is it <ok>? next');
      expect(flowchartWordsOf('{"ops":[{"insert":"x\\n"}]}'), '');
    });
  });

  group('FlowchartEditorScreen', () {
    Future<List<FlowchartResult?>> open(
      WidgetTester tester,
      Flowchart chart, {
      bool isNew = false,
    }) async {
      final results = <FlowchartResult?>[];
      tester.view.physicalSize = const Size(1080, 2160);
      tester.view.devicePixelRatio = 2.7;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () async => results.add(
                  await FlowchartEditorScreen.open(
                    context,
                    chart: chart,
                    colors: _colors,
                    isNew: isNew,
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      // The screen leaves alone the taps right after it opens.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 400)),
      );
      return results;
    }

    FlowchartPainter painter(WidgetTester tester) =>
        tester
                .widget<CustomPaint>(
                  find.descendant(
                    of: find.byKey(const ValueKey('flowchart-canvas')),
                    matching: find.byType(CustomPaint),
                  ),
                )
                .foregroundPainter!
            as FlowchartPainter;

    /// Where a point of the chart is on screen.
    Offset onScreen(WidgetTester tester, Offset point) {
      final p = painter(tester);
      final canvas = tester.getTopLeft(
        find.byKey(const ValueKey('flowchart-canvas')),
      );
      return canvas + point * p.scale + p.offset;
    }

    testWidgets('adds a step from a box, writes in it, and saves', (
      tester,
    ) async {
      final results = await open(tester, Flowchart.tryParse(_web)!);
      final decision = painter(tester).chart.node('b')!;

      // Tap to pick, then the dot under it for the next step.
      await tester.tapAt(onScreen(tester, decision.center));
      await tester.pumpAndSettle();
      expect(painter(tester).marks.pickedNode, 'b');
      final below = painter(tester).marks.handles[2];
      await tester.tapAt(onScreen(tester, below));
      await tester.pumpAndSettle();

      // The new step asks for its text straight away.
      await tester.enterText(find.byType(TextField), 'Ship it');
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      final chart = painter(tester).chart;
      expect(chart.nodes, hasLength(3));
      final step = chart.nodes.last;
      expect(step.text, 'Ship it');
      expect(step.y, greaterThan(decision.rect.bottom));
      expect(
        chart.edges.where((e) => e.from == 'b' && e.to == step.id),
        hasLength(1),
      );

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      final saved = results.single as FlowchartSaved;
      expect(saved.chart.nodes.map((n) => n.text), [
        'Start',
        'Is it <ok>?',
        'Ship it',
      ]);
    });

    testWidgets('drags a box, and undo puts it back', (tester) async {
      await open(tester, Flowchart.tryParse(_web)!);
      final start = painter(tester).chart.node('a')!;
      await tester.dragFrom(
        onScreen(tester, start.center),
        const Offset(120, 0),
      );
      await tester.pumpAndSettle();
      final moved = painter(tester).chart.node('a')!;
      expect(moved.x, greaterThan(start.x + 50));
      expect(moved.x % Flowchart.grid, 0);

      await tester.tap(find.bySemanticsLabel('Undo'));
      await tester.pumpAndSettle();
      expect(painter(tester).chart.node('a')!.x, start.x);
    });

    testWidgets('joins two boxes by dragging a dot onto one', (tester) async {
      final chart = Flowchart(
        nodes: const [
          FlowNode(id: 'a', x: 0, y: 0, text: 'One'),
          FlowNode(id: 'b', x: 260, y: 0, text: 'Two'),
        ],
      );
      await open(tester, chart);
      await tester.tapAt(onScreen(tester, const Offset(0, 0)));
      await tester.pumpAndSettle();
      final right = painter(tester).marks.handles[1];
      await tester.dragFrom(
        onScreen(tester, right),
        onScreen(tester, const Offset(260, 0)) - onScreen(tester, right),
      );
      await tester.pumpAndSettle();
      final edges = painter(tester).chart.edges;
      expect(edges.single.from, 'a');
      expect(edges.single.to, 'b');
    });

    testWidgets('asks before throwing changes away', (tester) async {
      final results = await open(tester, Flowchart.tryParse(_web)!);
      await tester.tapAt(onScreen(tester, const Offset(0, 0)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(painter(tester).chart.nodes, hasLength(1));

      await tester.tap(find.bySemanticsLabel('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(results, [null]);
    });
  });
}
