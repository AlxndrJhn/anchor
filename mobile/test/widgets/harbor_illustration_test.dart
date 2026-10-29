import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/features/server/presentation/harbor_illustration.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpScene(
    WidgetTester tester, {
    bool isMotionReduced = false,
  }) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: isMotionReduced),
            child: const Align(
              alignment: Alignment.topCenter,
              child: HarborIllustration(),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('the harbor spans the width and keeps moving', (tester) async {
    await pumpScene(tester);
    final size = tester.getSize(find.byType(HarborIllustration));
    expect(size.width, 360);
    expect(size.height, closeTo(252 * 360 / 412, 0.001));

    await tester.pump(const Duration(seconds: 2));
    expect(tester.binding.hasScheduledFrame, isTrue);
  });

  testWidgets('with reduced motion the harbor holds still', (tester) async {
    await pumpScene(tester, isMotionReduced: true);
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
