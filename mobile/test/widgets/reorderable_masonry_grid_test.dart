import 'dart:math';

import 'package:anchor/core/widgets/masonry/reorderable_masonry_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_test/flutter_test.dart';

const _count = 80;
const _spacing = 8.0;

/// Cards of many heights, as notes are.
final _heights = {
  for (var i = 0; i < _count; i++) 'n$i': 60.0 + (i * 37) % 220,
};

Widget _grid(List<String> ids, ScrollController controller) => MaterialApp(
  home: CustomScrollView(
    controller: controller,
    slivers: [
      ReorderableMasonryGrid(
        ids: ids,
        gridDelegate: const SliverSimpleGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
        ),
        mainAxisSpacing: _spacing,
        crossAxisSpacing: _spacing,
        delegate: SliverChildBuilderDelegate(
          (context, i) => SizedBox(
            key: ValueKey(ids[i]),
            height: _heights[ids[i]],
            child: Text(ids[i]),
          ),
          childCount: ids.length,
          findChildIndexCallback: (key) {
            final i = ids.indexWhere((id) => ValueKey(id) == key);
            return i < 0 ? null : i;
          },
        ),
      ),
    ],
  ),
);

/// Where each card belongs: in order, each into the shortest column.
Map<String, Offset> _masonry(List<String> ids, double width) {
  final columns = [0.0, 0.0];
  final stride = (width + _spacing) / 2;
  final places = <String, Offset>{};
  for (final id in ids) {
    final c = columns[0] <= columns[1] ? 0 : 1;
    places[id] = Offset(c * stride, columns[c]);
    columns[c] += _heights[id]! + _spacing;
  }
  return places;
}

/// The cards laid out now that aren't where they belong.
List<String> _misplaced(
  WidgetTester tester,
  List<String> ids,
  ScrollController controller,
) {
  final expected = _masonry(ids, 800);
  final origin =
      tester.getTopLeft(find.byType(CustomScrollView)) -
      Offset(0, controller.offset);
  return [
    for (final id in ids)
      if (find.text(id).evaluate().isNotEmpty &&
          (tester.getTopLeft(find.text(id)) - origin - expected[id]!).distance >
              0.5)
        id,
  ];
}

void main() {
  test('the first change in the order', () {
    expect(firstDifference(['a', 'b', 'c'], ['a', 'b', 'c']), isNull);
    expect(firstDifference(['a', 'b', 'c'], ['a', 'c', 'b']), 1);
    expect(firstDifference(['a', 'b'], ['a', 'b', 'c']), 2);
    expect(firstDifference(['b', 'c'], ['a', 'b', 'c']), 0);
  });

  for (final scroll in [0.0, 300.0, 900.0, 2500.0]) {
    testWidgets('cards moved with the list at $scroll are placed again', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      var ids = [for (var i = 0; i < _count; i++) 'n$i'];
      await tester.pumpWidget(_grid(ids, controller));
      controller.jumpTo(scroll);
      await tester.pumpAndSettle();
      final random = Random(scroll.toInt());

      for (var round = 0; round < 12; round++) {
        // A card on screen goes a few places up or down, as a drag does.
        final shown = [
          for (final id in ids)
            if (find.text(id).hitTestable().evaluate().isNotEmpty) id,
        ];
        final id = shown[random.nextInt(shown.length)];
        final from = ids.indexOf(id);
        final to = (from + random.nextInt(9) - 4).clamp(0, ids.length - 1);
        ids = [...ids]
          ..removeAt(from)
          ..insert(to, id);
        await tester.pumpWidget(_grid(ids, controller));
        await tester.pumpAndSettle();

        expect(
          _misplaced(tester, ids, controller),
          isEmpty,
          reason: 'round $round: $id from $from to $to',
        );
      }

      // And the list still reaches its last card.
      for (var i = 0; i < 6; i++) {
        controller.jumpTo(controller.position.maxScrollExtent);
        await tester.pumpAndSettle();
      }
      final expected = _masonry(ids, 800);
      final last = ids.reduce(
        (a, b) =>
            expected[a]!.dy + _heights[a]! >= expected[b]!.dy + _heights[b]!
            ? a
            : b,
      );
      expect(find.text(last).hitTestable(), findsOneWidget);
      expect(_misplaced(tester, ids, controller), isEmpty);
    });
  }
}
