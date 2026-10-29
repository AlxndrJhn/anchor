import 'package:anchor/core/widgets/trailing_wrap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpWrap(
    WidgetTester tester, {
    required List<double> widths,
    TextDirection direction = TextDirection.ltr,
  }) => tester.pumpWidget(
    Directionality(
      textDirection: direction,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 200,
          child: TrailingWrap(
            spacing: 6,
            runSpacing: 4,
            trailing: const SizedBox(key: Key('end'), width: 50, height: 10),
            children: [
              for (final (i, width) in widths.indexed)
                SizedBox(key: Key('$i'), width: width, height: 20),
            ],
          ),
        ),
      ),
    ),
  );

  testWidgets('the trailing child sits at the end of the last run', (
    tester,
  ) async {
    await pumpWrap(tester, widths: [40, 40]);

    expect(tester.getRect(find.byKey(const Key('1'))).left, 46);
    expect(
      tester.getRect(find.byKey(const Key('end'))),
      const Rect.fromLTWH(150, 5, 50, 10),
    );
  });

  testWidgets('it takes a run of its own at the end when it does not fit', (
    tester,
  ) async {
    await pumpWrap(tester, widths: [100, 60]);

    expect(
      tester.getRect(find.byKey(const Key('end'))),
      const Rect.fromLTWH(150, 24, 50, 10),
    );
    expect(tester.getSize(find.byType(TrailingWrap)), const Size(200, 34));
  });

  testWidgets('right to left, it sits at the left', (tester) async {
    await pumpWrap(tester, widths: [40], direction: TextDirection.rtl);

    expect(tester.getRect(find.byKey(const Key('0'))).right, 200);
    expect(tester.getRect(find.byKey(const Key('end'))).left, 0);
  });
}
