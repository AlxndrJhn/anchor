import 'package:anchor/core/motion/animated_resize.dart';
import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/core/widgets/reveal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget app(Widget child, {bool reducesMotion = false}) => MaterialApp(
  theme: AppTheme.light(),
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reducesMotion),
      child: Scaffold(body: child),
    ),
  ),
);

void main() {
  testWidgets('a reveal opens and closes with reduced motion on', (
    tester,
  ) async {
    Widget reveal({required bool isVisible}) => app(
      Column(
        children: [
          Reveal(
            visible: isVisible,
            child: const SizedBox(height: 120, child: Text('Inside')),
          ),
        ],
      ),
      reducesMotion: true,
    );

    await tester.pumpWidget(reveal(isVisible: false));
    await tester.pumpWidget(reveal(isVisible: true));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(Reveal)).height, 120);

    await tester.pumpWidget(reveal(isVisible: false));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(Reveal)).height, 0);
  });

  testWidgets('a resize asked to take no time still follows its child', (
    tester,
  ) async {
    Widget box(double height) => app(
      Column(
        children: [
          AnimatedResize(
            duration: Duration.zero,
            child: SizedBox(height: height, width: 40),
          ),
        ],
      ),
    );

    await tester.pumpWidget(box(40));
    await tester.pumpWidget(box(96));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(AnimatedResize)).height, 96);
  });
}
