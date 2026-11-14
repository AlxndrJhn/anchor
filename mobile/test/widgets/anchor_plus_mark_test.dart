import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/core/widgets/anchor_plus_mark.dart';
import 'package:anchor/core/widgets/page_heading.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpHeading(WidgetTester tester, {bool reduced = false}) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(40),
              child: PageHeading(
                title: 'Welcome to Anchor+',
                subtitle: 'Enter your server address to get started.',
                titleMark: AnchorPlusMark(size: AnchorPlusMark.titleSize),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Finder featureIcons() => find.byWidgetPredicate(
    (widget) => widget is Icon && AnchorPlusMark.features.contains(widget.icon),
  );

  testWidgets('screen readers hear the whole name, the + is drawn', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpHeading(tester);

    expect(find.bySemanticsLabel('Welcome to Anchor+'), findsOneWidget);
    expect(find.byType(AnchorPlusMark), findsOneWidget);
    expect(find.text('Welcome to Anchor+'), findsNothing);
    semantics.dispose();
  });

  testWidgets('the features fly out once on their own, and again on a tap', (
    tester,
  ) async {
    await pumpHeading(tester);
    expect(featureIcons(), findsNothing);

    await tester.pump(const Duration(milliseconds: 1000));
    expect(featureIcons(), findsNWidgets(AnchorPlusMark.features.length));
    await tester.pump(const Duration(milliseconds: 1500));
    expect(featureIcons(), findsNothing);

    await tester.tap(find.byType(AnchorPlusMark));
    await tester.pump(const Duration(milliseconds: 100));
    expect(featureIcons(), findsNWidgets(AnchorPlusMark.features.length));
    await tester.pump(const Duration(milliseconds: 1500));
    expect(featureIcons(), findsNothing);
  });

  testWidgets('a tap just beside the small + still reaches it', (tester) async {
    await pumpHeading(tester);
    // Past the burst it plays on its own.
    await tester.pump(const Duration(milliseconds: 2500));
    final center = tester.getCenter(find.byType(AnchorPlusMark));

    // 24 wide, with room to 48 on Android: 20 off its centre is outside
    // what's drawn, and outside the title's own box on the right, but
    // inside the target.
    for (final miss in const [Offset(20, 0), Offset(-20, 0), Offset(0, 20)]) {
      await tester.tapAt(center + miss);
      await tester.pump(const Duration(milliseconds: 100));
      expect(featureIcons(), findsNWidgets(AnchorPlusMark.features.length));
      await tester.pump(const Duration(milliseconds: 1500));
    }
  });

  testWidgets('it keeps hovering for as long as it shows', (tester) async {
    await pumpHeading(tester);
    expect(tester.hasRunningAnimations, isTrue);

    // Well past the twenty seconds it used to stop after.
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(tester.hasRunningAnimations, isTrue);
  });

  testWidgets('with reduced motion the + sits still', (tester) async {
    await pumpHeading(tester, reduced: true);

    await tester.pump(const Duration(seconds: 2));
    expect(featureIcons(), findsNothing);
    expect(tester.hasRunningAnimations, isFalse);
  });
}
