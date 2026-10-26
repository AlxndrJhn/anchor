import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/core/widgets/page_bar.dart';
import 'package:anchor/features/notes/presentation/widgets/note_bar.dart';
import 'package:anchor/features/notes/presentation/widgets/note_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpBar(
    WidgetTester tester, {
    required double width,
    bool hasArchiveAndDelete = true,
  }) async {
    tester.view
      ..physicalSize = Size(width, 700)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => Stack(
            children: [
              NoteBar(
                appearance: NoteAppearance.of(context, null),
                scrollOffset: ScrollOffset(ScrollController()),
                reminder: null,
                isUnsynced: true,
                isTrashed: false,
                isReadOnly: false,
                onBack: () {},
                onHistory: () {},
                onBackground: () {},
                onReminder: () {},
                onMore: () {},
                onArchive: hasArchiveAndDelete ? () {} : null,
                onTrash: hasArchiveAndDelete ? () {} : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('on a narrow phone the On this phone badge keeps only its '
      'icon, so it stays clear of the five buttons', (tester) async {
    await pumpBar(tester, width: 420);

    expect(find.text('On this phone'), findsNothing);
    expect(find.bySemanticsLabel('Changes not synced yet'), findsOneWidget);
    final back = tester.getRect(find.bySemanticsLabel('Back'));
    final archive = tester.getRect(find.bySemanticsLabel('Archive'));
    final badge = tester.getRect(
      find.bySemanticsLabel('Changes not synced yet'),
    );
    expect(badge.left, greaterThanOrEqualTo(back.right));
    expect(
      badge.right,
      lessThan(tester.getRect(find.bySemanticsLabel('Background')).left),
    );
    expect(archive.right, lessThanOrEqualTo(420));
  });

  testWidgets('with room to spare the badge says On this phone', (
    tester,
  ) async {
    await pumpBar(tester, width: 600);
    expect(find.text('On this phone'), findsOneWidget);

    // Without Archive and Delete, the width that hid its words is enough.
    await pumpBar(tester, width: 420, hasArchiveAndDelete: false);
    expect(find.text('On this phone'), findsOneWidget);
  });
}
