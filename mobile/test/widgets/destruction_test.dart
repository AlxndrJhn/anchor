import 'package:anchor/core/widgets/destruction/destruction.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('the burn', () {
    test('waits for the jolt, then reaches every block', () {
      expect(burnFront(0), 0);
      expect(burnFront(0.1), 0);
      expect(burnFront(0.5), greaterThan(0));
      // At the end even the last block (threshold 1) has burnt through.
      expect(blockStateAt(1, burnFront(1)), BlockState.gone);
    });

    test('past the end the sparks fly on and fade out', () {
      expect(burnFront(1.2), greaterThan(burnFront(1)));
      expect(sparkOpacity(1), 1);
      expect(sparkOpacity((1 + burnTailEnd) / 2), closeTo(0.5, 0.01));
      expect(sparkOpacity(burnTailEnd), 0);
    });

    test('a block glows at the edge before it goes', () {
      expect(blockStateAt(0.5, 0.3), BlockState.whole);
      expect(blockStateAt(0.5, 0.55), BlockState.burning);
      expect(blockStateAt(0.5, 0.9), BlockState.gone);
    });

    test('its pattern covers the card, from 0 to 1', () {
      final pattern = BurnPattern.forSize(const Size(180, 240), seed: 1);
      expect(pattern.columns * pattern.cell, greaterThanOrEqualTo(180));
      expect(pattern.rows * pattern.cell, greaterThanOrEqualTo(240));
      expect(pattern.thresholds.reduce((a, b) => a < b ? a : b), 0);
      expect(pattern.thresholds.reduce((a, b) => a > b ? a : b), 1);
    });
  });

  Future<void> pumpCards(
    WidgetTester tester, {
    required ValueNotifier<bool> shown,
    bool reduceMotion = false,
  }) => tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder(
            valueListenable: shown,
            builder: (context, isShown, _) => Column(
              children: [
                if (isShown)
                  const Destructible(
                    id: 'n1',
                    child: SizedBox(
                      width: 120,
                      height: 80,
                      child: ColoredBox(color: Colors.amber),
                    ),
                  ),
                const Text('Next card'),
                TextButton(
                  onPressed: () async {
                    await burnNoteCards(['n1', 'not-on-screen']);
                    shown.value = false;
                  },
                  child: const Text('Delete'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Finder burn() => find.byWidgetPredicate(
    (w) => w is CustomPaint && w.painter is BurnPainter,
  );

  testWidgets('a deleted card burns in place, then goes', (tester) async {
    final shown = ValueNotifier(true);
    await pumpCards(tester, shown: shown);
    final nextBefore = tester.getTopLeft(find.text('Next card'));

    await tester.tap(find.text('Delete'));
    await tester.pump();
    await tester.pump(destructionDuration ~/ 2);
    // Burning where it stood, keeping its place: the next card stays put.
    expect(burn(), findsOneWidget);
    expect(tester.getSize(find.byType(Destructible)), const Size(120, 80));
    expect(tester.getTopLeft(find.text('Next card')), nextBefore);

    await tester.pump(
      destructionDuration ~/ 2 + const Duration(milliseconds: 20),
    );
    await tester.pump();
    await tester.pump();
    // Burnt, it's deleted, and the next card moves up; its last sparks
    // fly on above it for a moment.
    expect(find.byType(Destructible), findsNothing);
    expect(
      tester.getTopLeft(find.text('Next card')).dy,
      lessThan(nextBefore.dy),
    );
    expect(burn(), findsOneWidget);

    await tester.pump(burnTailDuration ~/ 2);
    await tester.pump(burnTailDuration);
    // Then they're gone too.
    expect(burn(), findsNothing);
  });

  testWidgets('with the burn turned off in Settings, the card just goes', (
    tester,
  ) async {
    burnDeletedNotes = false;
    addTearDown(() => burnDeletedNotes = true);
    final shown = ValueNotifier(true);
    await pumpCards(tester, shown: shown);

    await tester.tap(find.text('Delete'));
    await tester.pump();

    expect(burn(), findsNothing);
    expect(find.byType(Destructible), findsNothing);
  });

  testWidgets('with animations turned off, the card just goes', (tester) async {
    final shown = ValueNotifier(true);
    await pumpCards(tester, shown: shown, reduceMotion: true);

    await tester.tap(find.text('Delete'));
    await tester.pump();

    expect(burn(), findsNothing);
    expect(find.byType(Destructible), findsNothing);
  });
}
