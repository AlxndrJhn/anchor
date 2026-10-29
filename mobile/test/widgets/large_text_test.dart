import 'dart:convert';

import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/core/widgets/anchor_sheet.dart';
import 'package:anchor/core/widgets/app_snackbar.dart';
import 'package:anchor/core/widgets/pill.dart';
import 'package:anchor/features/notes/domain/note.dart';
import 'package:anchor/features/notes/presentation/widgets/card_body.dart';
import 'package:anchor/features/notes/presentation/widgets/note_chips.dart';
import 'package:anchor/features/notes/presentation/widgets/note_surface.dart';
import 'package:anchor/features/tags/domain/tag.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Text drawn in a box shorter than the text, so its tops or bottoms are cut.
List<String> clippedTexts(WidgetTester tester) => [
  for (final paragraph in tester.renderObjectList<RenderParagraph>(
    find.byType(RichText),
  ))
    if (paragraph.getMaxIntrinsicHeight(paragraph.size.width) >
        paragraph.size.height + 0.5)
      paragraph.text.toPlainText(),
];

Future<void> pumpAt2x(WidgetTester tester, WidgetBuilder builder) async {
  tester.platformDispatcher.textScaleFactorTestValue = 2;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: Center(
          child: SizedBox(width: 360, child: Builder(builder: builder)),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('pills grow with large text', (tester) async {
    await pumpAt2x(tester, (_) => const Pill(label: 'Can edit'));

    expect(clippedTexts(tester), isEmpty);
  });

  testWidgets('tag and reminder chips grow with large text', (tester) async {
    await pumpAt2x(
      tester,
      (context) => Wrap(
        children: [
          for (final isSmall in [true, false]) ...[
            TagChip(
              tag: const Tag(id: 't1', name: 'family'),
              appearance: NoteAppearance.of(context, null),
              isSmall: isSmall,
            ),
            ReminderChip(
              reminder: const NoteReminder(
                remindAt: '2026-10-02T09:00',
                recurrence: ReminderRecurrence.none,
              ),
              appearance: NoteAppearance.of(context, null),
              isSmall: isSmall,
            ),
          ],
        ],
      ),
    );

    expect(clippedTexts(tester), isEmpty);
  });

  testWidgets('numbered lines on a card keep their numbers whole', (
    tester,
  ) async {
    final content = jsonEncode({
      'ops': [
        {'insert': 'Ship the sync fix'},
        {
          'insert': '\n',
          'attributes': {'list': 'ordered'},
        },
        {'insert': 'Retry the token'},
        {
          'insert': '\n',
          'attributes': {'list': 'ordered', 'indent': 1},
        },
      ],
    });
    await pumpAt2x(
      tester,
      (context) => CardBody(
        content: content,
        appearance: NoteAppearance.of(context, null),
        layout: CardLayout.list,
      ),
    );

    expect(find.text('1.'), findsOneWidget);
    expect(clippedTexts(tester), isEmpty);
  });

  testWidgets('a sheet title stays whole in its row', (tester) async {
    await pumpAt2x(tester, (_) => const SheetHeader(title: 'New tag'));

    expect(clippedTexts(tester), isEmpty);
  });

  testWidgets('a snackbar action grows with large text', (tester) async {
    await pumpAt2x(
      tester,
      (context) => TextButton(
        onPressed: () => AppSnackbar.show(
          context,
          'Archived',
          actionLabel: 'Undo',
          onAction: () {},
        ),
        child: const Text('Archive'),
      ),
    );
    await tester.tap(find.text('Archive'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Undo'), findsOneWidget);
    expect(clippedTexts(tester), isEmpty);
    await tester.pump(const Duration(seconds: 11));
  });
}
