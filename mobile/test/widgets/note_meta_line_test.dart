import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/core/widgets/person_avatar.dart';
import 'package:anchor/features/notes/domain/note.dart';
import 'package:anchor/features/notes/domain/note_share_permission.dart';
import 'package:anchor/features/notes/domain/user_summary.dart';
import 'package:anchor/features/notes/presentation/widgets/note_header.dart';
import 'package:anchor/features/notes/presentation/widgets/note_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

void main() {
  const note = Note(id: 'n1', title: 'Lisbon trip', shareIds: ['u2', 'u3']);
  const sam = UserSummary(id: 'u2', name: 'Sam Lee', email: 'sam@example.com');
  const pat = UserSummary(id: 'u3', name: 'Pat Moss', email: 'pat@example.com');

  Future<void> pumpLine(
    WidgetTester tester, {
    Note? shown,
    required List<UserSummary>? sharedWith,
  }) async {
    final words = ValueNotifier(12);
    addTearDown(words.dispose);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) => NoteMetaLine(
                note: shown ?? note,
                appearance: NoteAppearance.of(context, null),
                words: words,
                sharedWith: sharedWith,
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('a note you shared shows who has it', (tester) async {
    await pumpLine(tester, sharedWith: const [sam, pat]);

    expect(find.byType(PersonAvatar), findsNWidgets(2));
    expect(find.text('Shared with Sam and Pat'), findsOneWidget);
  });

  testWidgets('before the people load, it counts them', (tester) async {
    await pumpLine(tester, sharedWith: null);

    expect(find.byType(PersonAvatar), findsNothing);
    expect(find.byIcon(LucideIcons.users), findsOneWidget);
    expect(find.text('Shared with 2 people'), findsOneWidget);
  });

  testWidgets('says who a public link lets in, and what they can do', (
    tester,
  ) async {
    await pumpLine(tester, sharedWith: null);
    expect(find.byIcon(LucideIcons.globe), findsNothing);

    await pumpLine(
      tester,
      shown: note.copyWith(publicLink: NoteSharePermission.viewer),
      sharedWith: null,
    );
    expect(find.byIcon(LucideIcons.globe), findsOneWidget);
    expect(find.text('Public: anyone with the link can view'), findsOneWidget);

    await pumpLine(
      tester,
      shown: note.copyWith(publicLink: NoteSharePermission.editor),
      sharedWith: null,
    );
    expect(find.text('Public: anyone with the link can edit'), findsOneWidget);
  });

  testWidgets('a trashed note is not public: its link does not open', (
    tester,
  ) async {
    await pumpLine(
      tester,
      shown: note.copyWith(
        publicLink: NoteSharePermission.viewer,
        state: NoteState.trashed,
      ),
      sharedWith: null,
    );
    expect(find.byIcon(LucideIcons.globe), findsNothing);
  });
}
