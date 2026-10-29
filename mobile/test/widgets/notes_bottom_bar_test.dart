import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/features/notes/presentation/widgets/notes_bottom_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

void main() {
  Widget bar({required bool isCompact}) => MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: NotesBottomBar(
            placeholder: 'Search notes',
            compact: isCompact,
            searching: false,
            query: '',
            onStartSearch: () {},
            onQuery: (_) {},
            onCancel: () {},
            onNewNote: () {},
          ),
        ),
      ),
    ),
  );

  testWidgets('the search icon holds still while the pill grows and the '
      'words fade in', (tester) async {
    tester.view.physicalSize = const Size(360, 792);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(bar(isCompact: true));
    await tester.pumpAndSettle();
    final icon = find.byIcon(LucideIcons.search);
    final start = tester.getRect(icon).left;
    double wordsOpacity() => tester
        .widget<Opacity>(
          find.ancestor(
            of: find.text('Search notes'),
            matching: find.byType(Opacity),
          ),
        )
        .opacity;
    expect(wordsOpacity(), 0);

    await tester.pumpWidget(bar(isCompact: false));
    var last = 0.0;
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.getRect(icon).left, closeTo(start, 0.5));
      expect(wordsOpacity(), greaterThanOrEqualTo(last));
      last = wordsOpacity();
    }
    expect(last, 1);
  });
}
