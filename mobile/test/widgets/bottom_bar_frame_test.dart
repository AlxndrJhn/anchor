import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/core/theme/display_density.dart';
import 'package:anchor/core/widgets/app_buttons.dart';
import 'package:anchor/core/widgets/app_scaffold.dart';
import 'package:anchor/core/widgets/app_snackbar.dart';
import 'package:anchor/core/widgets/app_text_field.dart';
import 'package:anchor/core/widgets/selection_bar.dart';
import 'package:anchor/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget pageWithBottomBar([DisplayDensity density = DisplayDensity.standard]) =>
    MaterialApp(
      theme: AppTheme.light(density),
      home: Builder(
        builder: (context) => AppScaffold(
          title: 'Docked',
          bottomBar: AppButton(label: 'Save', onPressed: () {}),
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  TextButton(
                    onPressed: () => AppSnackbar.show(context, 'Saved here'),
                    child: const Text('Show'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const _Plain()),
                    ),
                    child: const Text('Open'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

class _Plain extends StatelessWidget {
  const _Plain();

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Plain',
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            children: [
              TextButton(
                onPressed: () => AppSnackbar.show(context, 'Plain here'),
                child: const Text('Show here'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  AppSnackbar.show(context, 'Back there');
                },
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Lets a snackbar come up; it keeps a clock, so it never settles.
Future<void> pumpSnackbarIn(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> pumpUntilSnackbarCloses(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 7));
  await tester.pumpAndSettle();
}

final _english = lookupAppLocalizations(const Locale('en'));

void main() {
  for (final (density, gap) in [
    (DisplayDensity.standard, 12.0),
    (DisplayDensity.compact, 8.0),
  ]) {
    testWidgets('a snackbar sits $gap clear of the page dock in '
        '${density.labelIn(_english)}', (tester) async {
      await tester.pumpWidget(pageWithBottomBar(density));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Show'));
      await pumpSnackbarIn(tester);

      final snackbar = tester.getRect(
        find
            .ancestor(
              of: find.text('Saved here'),
              matching: find.byType(Material),
            )
            .first,
      );
      final saveButton = tester.getRect(
        find.ancestor(of: find.text('Save'), matching: find.byType(AppButton)),
      );
      expect(saveButton.top - snackbar.bottom, closeTo(gap, 0.5));
      await pumpUntilSnackbarCloses(tester);
    });
  }

  testWidgets('a page without a dock keeps its snackbar at the bottom', (
    tester,
  ) async {
    await tester.pumpWidget(pageWithBottomBar());
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Show here'));
    await pumpSnackbarIn(tester);

    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    final snackBottom = tester.getBottomLeft(find.text('Plain here')).dy;
    expect(snackBottom, greaterThan(screen.height - 60));
    await pumpUntilSnackbarCloses(tester);
  });

  testWidgets(
    'a snackbar shown as a page closes sits above the dock under it',
    (tester) async {
      await tester.pumpWidget(pageWithBottomBar());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Close'));
      await pumpSnackbarIn(tester);

      final saveButton = tester.getRect(
        find.ancestor(of: find.text('Save'), matching: find.byType(AppButton)),
      );
      final snackBottom = tester.getBottomLeft(find.text('Back there')).dy;
      expect(saveButton.top - snackBottom, greaterThanOrEqualTo(16));
      await pumpUntilSnackbarCloses(tester);
    },
  );

  testWidgets('the page ends 16 above its dock', (tester) async {
    await tester.pumpWidget(pageWithBottomBar());
    await tester.pumpAndSettle();

    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
    await tester.pumpAndSettle();

    final saveButton = tester.getRect(
      find.ancestor(of: find.text('Save'), matching: find.byType(AppButton)),
    );
    final lastButton = tester.getRect(find.text('Open'));
    expect(lastButton.bottom, lessThanOrEqualTo(saveButton.top - 16));
  });

  testWidgets('a page at its end stays 16 above its dock as the dock grows', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    Widget page({required bool isSelecting}) => MaterialApp(
      theme: AppTheme.light(),
      home: AppScaffold(
        title: 'Long',
        controller: controller,
        bottomBar: SelectionBarSwitcher(
          isSelecting: isSelecting,
          bottomBar: const SizedBox(height: 52, child: Text('Dock')),
          selectionBar: const SizedBox(height: 64, child: Text('Bar')),
        ),
        slivers: [
          SliverList.list(
            children: [
              for (var i = 0; i < 30; i++)
                SizedBox(height: 48, child: Text('Row $i')),
            ],
          ),
        ],
      ),
    );
    double gapUnderLastRow() =>
        tester.getRect(find.byType(SelectionBarSwitcher)).top -
        tester.getRect(find.text('Row 29')).bottom;

    await tester.pumpWidget(page(isSelecting: false));
    await tester.pumpAndSettle();
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(gapUnderLastRow(), 16);

    await tester.pumpWidget(page(isSelecting: true));
    await tester.pumpAndSettle();
    expect(gapUnderLastRow(), 16);
  });

  for (final density in DisplayDensity.values) {
    testWidgets('a snackbar centers its icon and words (${density.name})', (
      tester,
    ) async {
      await tester.pumpWidget(pageWithBottomBar(density));
      await tester.tap(find.text('Show'));
      await pumpSnackbarIn(tester);
      final box = find.ancestor(
        of: find.text('Saved here'),
        matching: find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration! as BoxDecoration).borderRadius != null,
        ),
      );
      final middle = tester.getCenter(box.first).dy;
      expect(tester.getCenter(find.byType(Icon).last).dy, closeTo(middle, 0.5));
      expect(
        tester.getCenter(find.text('Saved here')).dy,
        closeTo(middle, 0.5),
      );
      await pumpUntilSnackbarCloses(tester);
    });
  }

  testWidgets('a focused field scrolls clear of the dock above the keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    tester.view.viewInsets = const FakeViewPadding(bottom: 300 * 3);
    addTearDown(tester.view.reset);
    final last = FocusNode();
    addTearDown(last.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: AppScaffold(
          title: 'Form',
          bottomBar: AppButton(label: 'Save', onPressed: () {}),
          slivers: [
            SliverList.list(
              children: [
                for (var i = 0; i < 6; i++)
                  AppTextField(
                    controller: TextEditingController(),
                    label: 'Field $i',
                    focusNode: i == 5 ? last : null,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
    last.requestFocus();
    await tester.pumpAndSettle();

    final bottomBarTop = tester.getRect(find.byType(AppButton)).top;
    final field = find.byWidgetPredicate(
      (widget) => widget is AppTextField && widget.label == 'Field 5',
    );
    expect(tester.getRect(field).bottom, lessThanOrEqualTo(bottomBarTop));
  });
}
