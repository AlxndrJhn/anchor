import 'package:anchor/core/widgets/sliver_masonry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final built = <int>{};

  Widget masonry(List<double> heights, {List<Object>? keys}) => SliverMasonry(
    itemKeys: keys ?? [for (var i = 0; i < heights.length; i++) 'item $i'],
    mainAxisSpacing: 12,
    crossAxisSpacing: 12,
    itemBuilder: (context, i) {
      built.add(i);
      return SizedBox(key: ValueKey(i), height: heights[i]);
    },
  );

  Future<ScrollController> pumpBoard(
    WidgetTester tester,
    List<Widget> groups,
  ) async {
    tester.view.physicalSize = const Size(360, 792);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: CustomScrollView(
          controller: controller,
          slivers: [
            const SliverToBoxAdapter(child: SizedBox(height: 150)),
            SliverMainAxisGroup(slivers: groups),
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
    return controller;
  }

  final long = [for (var i = 0; i < 80; i++) 120.0 + (i * 37 % 300)];

  for (final pinned in [
    [500.0],
    [500.0, 250.0],
    [500.0, 250.0, 300.0],
  ]) {
    testWidgets(
      'scrolls past a group of ${pinned.length} without snapping back',
      (tester) async {
        final controller = await pumpBoard(tester, [
          masonry(pinned),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
          masonry(long),
        ]);
        final max = controller.position.maxScrollExtent;
        expect(max, greaterThan(5000));
        for (var y = 0.0; y <= max; y += 9) {
          controller.jumpTo(y);
          await tester.pump();
          expect(controller.offset, y, reason: 'scrolled to $y');
        }
        for (var y = max; y >= 0; y -= 9) {
          controller.jumpTo(y);
          await tester.pump();
          expect(controller.offset, y, reason: 'scrolled back to $y');
        }
      },
    );
  }

  testWidgets('a fling keeps moving the same way until it stops', (
    tester,
  ) async {
    final controller = await pumpBoard(tester, [
      masonry([500, 250]),
      masonry(long),
    ]);
    await tester.fling(
      find.byType(CustomScrollView),
      const Offset(0, -300),
      3000,
    );
    var last = controller.offset;
    for (var frame = 0; frame < 120; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(controller.offset, greaterThanOrEqualTo(last));
      last = controller.offset;
    }
    expect(last, greaterThan(1500));
  });

  testWidgets('puts each child in the shortest column', (tester) async {
    await pumpBoard(tester, [
      masonry([100, 300, 100, 100, 50]),
    ]);
    Offset at(int i) => tester.getTopLeft(find.byKey(ValueKey(i)));
    const top = 150.0;
    expect(at(0), const Offset(0, top));
    expect(at(1), const Offset(186, top));
    expect(at(2), const Offset(0, top + 112));
    expect(at(3), const Offset(0, top + 224));
    expect(at(4), const Offset(186, top + 312));
  });

  testWidgets('keeps only the children near the screen', (tester) async {
    built.clear();
    final controller = await pumpBoard(tester, [
      masonry([for (var i = 0; i < 400; i++) 150]),
    ]);
    expect(built.length, lessThan(30));
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();
    expect(controller.position.maxScrollExtent, 200 * 162 - 12 + 270 - 792);
    expect(
      find.byType(SizedBox, skipOffstage: false).evaluate().length,
      lessThan(30),
    );
  });

  testWidgets('keeps its places when the children change order', (
    tester,
  ) async {
    final heights = [for (var i = 0; i < 40; i++) 100.0 + i * 7];
    final keys = [for (var i = 0; i < 40; i++) 'note $i'];
    final controller = await pumpBoard(tester, [masonry(heights, keys: keys)]);
    controller.jumpTo(1500);
    await tester.pump();
    final swapped = [heights[39], ...heights.sublist(0, 39)];
    final swappedKeys = [keys[39], ...keys.sublist(0, 39)];
    await tester.pumpWidget(
      MaterialApp(
        home: CustomScrollView(
          controller: controller,
          slivers: [
            const SliverToBoxAdapter(child: SizedBox(height: 150)),
            SliverMainAxisGroup(slivers: [masonry(swapped, keys: swappedKeys)]),
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
    expect(controller.offset, 1500);
    controller.jumpTo(0);
    await tester.pump();
    expect(tester.getTopLeft(find.byKey(const ValueKey(0))).dy, 150);
    expect(tester.getSize(find.byKey(const ValueKey(0))).height, 373);
  });
}
