import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/core/theme/app_typography.dart';
import 'package:anchor/core/theme/display_density.dart';
import 'package:anchor/core/widgets/app_buttons.dart';
import 'package:anchor/core/widgets/app_scaffold.dart';
import 'package:anchor/core/widgets/bar_title.dart';
import 'package:anchor/core/widgets/cap_height_text.dart';
import 'package:anchor/core/widgets/page_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final scroll = ScrollController();
  var builds = 0;

  Future<void> pumpPage(WidgetTester tester) async {
    builds = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: AppScaffold(
          title: 'Notes',
          controller: scroll,
          largeTitle: Builder(
            builder: (context) {
              builds++;
              return GestureDetector(onTap: () {}, child: const Text('Large'));
            },
          ),
          barTitle: GestureDetector(onTap: () {}, child: const Text('Small')),
          slivers: [
            SliverList.list(
              children: [for (var i = 0; i < 40; i++) Text('Row $i')],
            ),
          ],
        ),
      ),
    );
  }

  double opacityOf(WidgetTester tester, String text) => tester
      .widget<Opacity>(
        find.ancestor(of: find.text(text), matching: find.byType(Opacity)),
      )
      .opacity;

  bool isTappable(WidgetTester tester, String text) =>
      find.text(text).hitTestable().evaluate().isNotEmpty;

  testWidgets('the large title hands over to the bar title', (tester) async {
    await pumpPage(tester);
    expect(opacityOf(tester, 'Large'), 1);
    expect(opacityOf(tester, 'Small'), 0);
    expect(isTappable(tester, 'Large'), isTrue);
    expect(isTappable(tester, 'Small'), isFalse);

    scroll.jumpTo(PageBar.titleTransitionDistance * 0.25);
    await tester.pump();
    expect(opacityOf(tester, 'Large'), closeTo(0.55, 0.001));
    expect(opacityOf(tester, 'Small'), 0);

    scroll.jumpTo(PageBar.titleTransitionDistance * 0.75);
    await tester.pump();
    expect(opacityOf(tester, 'Large'), 0);
    expect(opacityOf(tester, 'Small'), closeTo(0.5, 0.001));
    expect(isTappable(tester, 'Large'), isFalse);
    expect(isTappable(tester, 'Small'), isTrue);

    scroll.jumpTo(300);
    await tester.pump();
    expect(opacityOf(tester, 'Small'), 1);
    expect(builds, 1, reason: 'scrolling only moves the titles');
  });

  testWidgets('a tall bar shrinks to the regular bar as its large title '
      'hands over', (tester) async {
    final controller = ScrollController();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: AppScaffold(
          title: 'Notes',
          isTall: true,
          controller: controller,
          largeTitle: const Text('Large'),
          barTitle: const Text('Small'),
          actions: [
            BarButton(icon: Icons.grid_view, label: 'View', onPressed: () {}),
          ],
          slivers: [
            SliverList.list(
              children: [for (var i = 0; i < 40; i++) Text('Row $i')],
            ),
          ],
        ),
      ),
    );
    double bar() => tester.getSize(find.byType(PageBar)).height;
    double button() => tester.getCenter(find.byType(BarButton)).dy;

    expect(bar(), 60);
    expect(button(), 30);
    expect(tester.getTopLeft(find.text('Row 0')).dy, 60);

    controller.jumpTo(PageBar.titleTransitionDistance / 2);
    await tester.pump();
    expect(bar(), 56);
    expect(button(), 28);
    expect(tester.getTopLeft(find.text('Row 0')).dy, 60 - 28);

    controller.jumpTo(300);
    await tester.pump();
    expect(bar(), 52);
    expect(button(), 26);

    controller.jumpTo(0);
    await tester.pump();
    expect(bar(), 60);
  });

  testWidgets('the bar frosts once something scrolls under it', (tester) async {
    await pumpPage(tester);
    BackdropFilter frost() => tester.widget(find.byType(BackdropFilter));
    double tint() => tester
        .widget<AnimatedOpacity>(
          find.descendant(
            of: find.byType(BackdropFilter),
            matching: find.byType(AnimatedOpacity),
          ),
        )
        .opacity;

    expect(frost().enabled, isFalse);
    expect(tint(), 0);

    scroll.jumpTo(3);
    await tester.pumpAndSettle();
    expect(frost().enabled, isTrue);
    expect(tint(), 1);

    scroll.jumpTo(0);
    await tester.pumpAndSettle();
    expect(frost().enabled, isFalse);
  });

  testWidgets('the bar stops blurring while the keyboard is up', (
    tester,
  ) async {
    await pumpPage(tester);
    scroll.jumpTo(300);
    await tester.pumpAndSettle();
    BackdropFilter frost() => tester.widget(find.byType(BackdropFilter));
    expect(frost().enabled, isTrue);

    tester.view.viewInsets = const FakeViewPadding(bottom: 900);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();
    expect(frost().enabled, isFalse);

    tester.view.resetViewInsets();
    await tester.pump();
    expect(frost().enabled, isTrue);
  });

  testWidgets('the bar clears once closing the keyboard settles the page '
      'back at the top', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = ScrollController();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: AppScaffold(
          title: 'Server',
          isTitleShown: false,
          showBack: false,
          controller: controller,
          slivers: const [SliverToBoxAdapter(child: SizedBox(height: 500))],
        ),
      ),
    );
    double tint() => tester
        .widget<AnimatedOpacity>(
          find.descendant(
            of: find.byType(BackdropFilter),
            matching: find.byType(AnimatedOpacity),
          ),
        )
        .opacity;

    tester.view.viewInsets = const FakeViewPadding(bottom: 400);
    await tester.pumpAndSettle();
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(tint(), 1);

    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    expect(controller.offset, 0);
    expect(tint(), 0);
  });

  testWidgets('with a dialog over the page, the bar hides what is under it', (
    tester,
  ) async {
    await pumpPage(tester);
    scroll.jumpTo(300);
    await tester.pumpAndSettle();
    Color fill() {
      final box = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(BackdropFilter),
          matching: find.byType(DecoratedBox),
        ),
      );
      return (box.decoration as BoxDecoration).color!;
    }

    expect(fill().a, lessThan(1));

    showDialog<void>(
      context: tester.element(find.text('Small')),
      builder: (_) => const Text('Dialog'),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<BackdropFilter>(find.byType(BackdropFilter)).enabled,
      isFalse,
    );
    expect(fill().a, 1);
  });

  testWidgets(
    'CapHeightText is as tall as its capitals, with the baseline at its '
    'foot',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CapHeightText('Notes', style: AppTypography.largeTitle),
                  CapHeightText('11 notes', style: AppTypography.footnote),
                ],
              ),
            ),
          ),
        ),
      );

      for (final (text, style) in [
        ('Notes', AppTypography.largeTitle),
        ('11 notes', AppTypography.footnote),
      ]) {
        final box = tester.getRect(find.widgetWithText(CapHeightText, text));
        expect(
          box.height,
          closeTo(
            AppTypography.capHeightOf(style.fontFamily) * style.fontSize! * 1.5,
            0.001,
          ),
        );
        final paragraph = tester.renderObject<RenderParagraph>(find.text(text));
        final painter = TextPainter(
          text: paragraph.text,
          textDirection: TextDirection.ltr,
          textScaler: paragraph.textScaler,
        )..layout();
        final baseline = paragraph
            .localToGlobal(
              Offset(
                0,
                painter.computeDistanceToActualBaseline(
                  TextBaseline.alphabetic,
                ),
              ),
            )
            .dy;
        painter.dispose();
        expect(baseline, closeTo(box.bottom, 0.001));
      }
    },
  );

  testWidgets('large text shrinks the title block to fit a Compact bar', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(DisplayDensity.compact),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: PageBar(
            isTall: true,
            largeTitle: LargeBarTitle(
              'Notes',
              line: const BarTitleLine('11 notes'),
              onTap: () {},
              semanticLabel: 'Notes, open menu',
            ),
          ),
        ),
      ),
    );
    final title = tester.getRect(find.widgetWithText(CapHeightText, 'Notes'));
    final line = tester.getRect(find.widgetWithText(CapHeightText, '11 notes'));
    expect(line.bottom - title.top, lessThanOrEqualTo(52.001));
    expect((title.top + line.bottom) / 2, closeTo(26, 0.001));
  });

  testWidgets('a page with nothing in its bar keeps only the status bar', (
    tester,
  ) async {
    final controller = ScrollController();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: MediaQuery(
          data: const MediaQueryData(padding: EdgeInsets.only(top: 59)),
          child: AppScaffold(
            title: 'Sign in',
            isTitleShown: false,
            showBack: false,
            controller: controller,
            slivers: [
              SliverList.list(
                children: [for (var i = 0; i < 40; i++) Text('Row $i')],
              ),
            ],
          ),
        ),
      ),
    );
    expect(tester.getTopLeft(find.text('Row 0')).dy, 59 + 8);
    expect(tester.getSize(find.byType(PageBar)).height, 59);

    controller.jumpTo(100);
    await tester.pumpAndSettle();
    final borders = tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(PageBar),
            matching: find.byType(DecoratedBox),
          ),
        )
        .map((box) => box.decoration)
        .whereType<BoxDecoration>()
        .where((decoration) => decoration.border != null);
    expect(borders, isEmpty);
  });
}
