import 'package:anchor/features/notes/presentation/editor/note_zoom.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('clampNoteZoom', () {
    test('keeps the zoom between its own size and the most', () {
      expect(clampNoteZoom(0.5), minNoteZoom);
      expect(clampNoteZoom(9), maxNoteZoom);
      expect(clampNoteZoom(1.8), 1.8);
      expect(clampNoteZoom(double.nan), minNoteZoom);
    });

    test('lets go at its own size just above it', () {
      expect(clampNoteZoom(1.04), 1);
      expect(clampNoteZoom(1.2), 1.2);
    });
  });

  testWidgets('a zoomed box wraps narrower and grows', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 200,
            child: ZoomedBox(
              zoom: 2,
              child: LayoutBuilder(
                builder: (context, constraints) => GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => taps++,
                  child: SizedBox(
                    key: const Key('child'),
                    width: constraints.maxWidth,
                    height: 30,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final child = find.byKey(const Key('child'));
    expect(tester.getSize(child), const Size(100, 30));
    expect(tester.getRect(child), const Rect.fromLTWH(0, 0, 200, 60));
    expect(tester.getSize(find.byType(ZoomedBox)), const Size(200, 60));

    // The lower half of the drawn box is still the child.
    await tester.tapAt(const Offset(190, 55));
    expect(taps, 1);
  });

  testWidgets('two fingers zoom the body, one scrolls', (tester) async {
    final zoom = ValueNotifier<double>(1);
    final isPinching = ValueNotifier(false);
    final scroll = ScrollController();
    final box = GlobalKey();
    double? saved;
    addTearDown(() {
      zoom.dispose();
      isPinching.dispose();
      scroll.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: PinchZoom(
          zoom: zoom,
          box: box,
          scroll: scroll,
          isPinching: isPinching,
          onZoomEnd: (value) => saved = value,
          child: ValueListenableBuilder(
            valueListenable: isPinching,
            builder: (context, pinching, _) => CustomScrollView(
              controller: scroll,
              physics: pinching
                  ? const NeverScrollableScrollPhysics()
                  : const ClampingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: ValueListenableBuilder(
                    valueListenable: zoom,
                    builder: (context, value, child) =>
                        ZoomedBox(key: box, zoom: value, child: child),
                    child: Column(
                      children: [
                        for (var i = 0; i < 60; i++)
                          SizedBox(height: 40, child: Text('Line $i')),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // One finger scrolls.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(scroll.offset, greaterThan(0));
    expect(zoom.value, 1);

    final before = scroll.offset;
    final first = await tester.startGesture(const Offset(200, 250));
    final second = await tester.startGesture(const Offset(200, 350));
    await tester.pump();
    expect(isPinching.value, isTrue);

    // Fingers twice as far apart, around the same middle.
    await first.moveTo(const Offset(200, 200));
    await second.moveTo(const Offset(200, 400));
    await tester.pump();
    expect(zoom.value, closeTo(2, 0.001));
    // The line between the fingers (y=300) stays there.
    expect(scroll.offset, closeTo((before + 300) * 2 - 300, 0.5));

    // Moving both fingers up carries the text along.
    final zoomed = scroll.offset;
    await first.moveTo(const Offset(200, 150));
    await second.moveTo(const Offset(200, 350));
    await tester.pump();
    expect(zoom.value, closeTo(2, 0.001));
    expect(scroll.offset, closeTo(zoomed + 50, 0.5));

    await first.up();
    await second.up();
    await tester.pump();
    expect(isPinching.value, isFalse);
    expect(saved, closeTo(2, 0.001));

    // Pinching back past its own size settles there.
    final a = await tester.startGesture(const Offset(200, 100));
    final b = await tester.startGesture(const Offset(200, 500));
    await a.moveTo(const Offset(200, 290));
    await b.moveTo(const Offset(200, 310));
    await a.up();
    await b.up();
    await tester.pumpAndSettle();
    expect(zoom.value, 1);
    expect(saved, 1);
  });
}
