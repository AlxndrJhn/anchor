import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/features/notes/presentation/widgets/note_options_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpSheet(
    WidgetTester tester, {
    bool isReadOnly = false,
    bool isTrashed = false,
    VoidCallback? onShareTap,
    int shareCount = 0,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: NoteOptionsSheet(
            isReadOnly: isReadOnly,
            isTrashed: isTrashed,
            shareCount: shareCount,
            onTagsTap: () {},
            onReminderTap: () {},
            onBackgroundTap: () {},
            onAttachmentTap: () {},
            onShareTap: onShareTap,
            onSendTap: () {},
          ),
        ),
      ),
    );
  }

  testWidgets(
    'the owner can tag and share; archive and delete are in the bar',
    (tester) async {
      await pumpSheet(tester, onShareTap: () {});

      expect(find.text('Tags'), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);
      expect(find.text('Archive'), findsNothing);
      expect(find.text('Delete'), findsNothing);
    },
  );

  testWidgets('Share says how many people the note is shared with', (
    tester,
  ) async {
    await pumpSheet(tester, onShareTap: () {}, shareCount: 2);

    expect(find.text('Shared with 2'), findsOneWidget);
  });

  testWidgets('someone the note is shared with cannot share it on', (
    tester,
  ) async {
    await pumpSheet(tester, isReadOnly: true);

    expect(find.text('Tags'), findsOneWidget);
    expect(find.text('Reminder'), findsOneWidget);
    expect(find.text('Share'), findsNothing);
    expect(find.text('Background'), findsNothing);
  });

  testWidgets('a trashed note offers none of them', (tester) async {
    await pumpSheet(tester, isReadOnly: true, isTrashed: true);

    expect(find.text('Tags'), findsNothing);
    expect(find.text('Reminder'), findsNothing);
    expect(find.text('Share'), findsNothing);
  });
}
