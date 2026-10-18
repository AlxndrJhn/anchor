import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/core/widgets/shimmer.dart';
import 'package:anchor/features/notes/presentation/widgets/card_body.dart';
import 'package:anchor/features/notes/presentation/widgets/note_cards_loading.dart';
import 'package:anchor/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    CardLayout layout, {
    bool isMotionReduced = false,
  }) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: isMotionReduced),
            child: Scaffold(
              body: SingleChildScrollView(
                child: NoteCardsLoading(layout: layout),
              ),
            ),
          ),
        ),
      ),
    );
  }

  double opacity(WidgetTester tester) => tester
      .widget<AnimatedOpacity>(
        find.descendant(
          of: find.byType(NoteCardsLoading),
          matching: find.byType(AnimatedOpacity),
        ),
      )
      .opacity;

  testWidgets('nothing shows for a quick load', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, CardLayout.masonry);
    await tester.pump(
      NoteCardsLoading.holdBack - const Duration(milliseconds: 10),
    );
    expect(opacity(tester), 0);

    await tester.pump(const Duration(milliseconds: 20));
    expect(opacity(tester), 1);
    expect(find.bySemanticsLabel('Loading notes'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('the shapes stand where the cards of each view go', (
    tester,
  ) async {
    for (final (layout, count, columns) in [
      (CardLayout.masonry, 8, 2),
      (CardLayout.grid, 8, 2),
      (CardLayout.list, 7, 1),
    ]) {
      await pump(tester, layout);
      await tester.pump(const Duration(milliseconds: 400));
      final cards = [
        for (final element in find.byType(Shimmer).evaluate())
          tester.getRect(find.byWidget(element.widget)),
      ];
      expect(cards, hasLength(count), reason: layout.name);
      expect(
        cards.map((card) => card.left).toSet(),
        hasLength(columns),
        reason: layout.name,
      );
      expect(
        cards.map((card) => card.width).toSet(),
        hasLength(1),
        reason: layout.name,
      );
    }
  });

  testWidgets('with less motion the shapes hold still', (tester) async {
    await pump(tester, CardLayout.list, isMotionReduced: true);
    await tester.pump(const Duration(milliseconds: 400));
    expect(opacity(tester), 1);
    expect(tester.binding.transientCallbackCount, 0);
  });
}
