import 'package:anchor/core/widgets/destruction/strike.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(disarmCardStrike);

  group('a struck card', () {
    const from = Offset(0, 100);

    test('starts where it was and speeds up to its place', () {
      expect(strikeOffset(from, Duration.zero), from);
      final half = strikeOffset(from, strikeTravel * 0.5);
      // Slow at first: less than half the way in half the time.
      expect(half.dy, greaterThan(50));
      expect(strikeOffset(from, strikeTravel), Offset.zero);
    });

    test('knocks back a little toward where it came from, then settles', () {
      final knocked = strikeOffset(from, strikeTravel + strikeBounce * 0.5);
      expect(knocked.dy, greaterThan(0));
      expect(knocked.dy, lessThanOrEqualTo(6));
      expect(strikeOffset(from, strikeTravel + strikeBounce), Offset.zero);
    });
  });

  Future<int> deleteFirst(WidgetTester tester, {required bool armed}) async {
    var knocks = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') knocks++;
        return null;
      },
    );
    final ids = ValueNotifier(['a', 'b', 'c']);
    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder(
          valueListenable: ids,
          builder: (context, shown, _) => ListView(
            addRepaintBoundaries: false,
            children: [
              for (final id in shown)
                Strike(
                  key: ValueKey(id),
                  child: SizedBox(height: 80, child: Text(id)),
                ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (armed) armCardStrike();
    ids.value = ['b', 'c'];
    // The frame that finds the cards moved shows them where they were, and
    // the strike starts after it.
    await tester.pump();
    final striking = tester.hasRunningAnimations;
    // And it ends.
    await tester.pumpAndSettle();
    expect(striking, armed);
    return knocks;
  }

  testWidgets('after a delete, the cards that move strike into place', (
    tester,
  ) async {
    expect(await deleteFirst(tester, armed: true), 1);
  });

  testWidgets('cards that move otherwise just go there', (tester) async {
    expect(await deleteFirst(tester, armed: false), 0);
  });
}
