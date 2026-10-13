import 'package:anchor/core/widgets/expanded_hit_area.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a tap near the child lands on it; the layout keeps its size', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 100, height: 40),
              ExpandedHitArea(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => taps++,
                  child: const SizedBox(width: 100, height: 20),
                ),
              ),
              const SizedBox(width: 100, height: 40),
            ],
          ),
        ),
      ),
    );
    final box = tester.getRect(find.byType(ExpandedHitArea));
    expect(box.height, 20);

    await tester.tapAt(box.topCenter - const Offset(0, 10));
    await tester.tapAt(box.bottomCenter + const Offset(0, 10));
    expect(taps, 2);

    await tester.tapAt(box.topCenter - const Offset(0, 14));
    expect(taps, 2);
  });
}
