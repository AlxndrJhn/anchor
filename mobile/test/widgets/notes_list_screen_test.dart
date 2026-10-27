import 'package:anchor/app/app_bootstrap.dart';
import 'package:anchor/core/network/connectivity_provider.dart';
import 'package:anchor/core/network/server_config_provider.dart';
import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/core/widgets/destruction/destruction.dart';
import 'package:anchor/features/auth/domain/user.dart';
import 'package:anchor/features/auth/presentation/auth_controller.dart';
import 'package:anchor/features/notes/data/repository/notes_repository.dart';
import 'package:anchor/features/notes/domain/note.dart';
import 'package:anchor/features/notes/presentation/note_folder.dart';
import 'package:anchor/features/notes/presentation/notes_controller.dart';
import 'package:anchor/features/notes/presentation/notes_list_screen.dart';
import 'package:anchor/features/notes/presentation/notes_view_options.dart';
import 'package:anchor/features/notes/presentation/widgets/note_card.dart';
import 'package:anchor/features/picture_search/picture_search.dart';
import 'package:anchor/features/reminders/data/reminder_permissions.dart';
import 'package:anchor/features/settings/domain/editor_preferences.dart';
import 'package:anchor/features/sync/data/sync_compatibility.dart';
import 'package:anchor/features/sync/data/sync_manager.dart';
import 'package:anchor/features/tags/domain/tag.dart';
import 'package:anchor/features/tags/presentation/tags_controller.dart';
import 'package:flutter/gestures.dart' show kDoubleTapTimeout;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockNotesRepository extends Mock implements NotesRepository {}

class _MockPictureSearchRepository extends Mock
    implements PictureSearchRepository {}

void main() {
  String delta(String text) => '{"ops":[{"insert":"$text\\n"}]}';
  List<Note> notesNamed(String prefix, int count) => [
    for (var i = 0; i < count; i++)
      Note(
        id: '$prefix$i',
        title: '$prefix $i',
        content: delta('text $i'),
        // Newest first: Note 0 is on top.
        updatedAt: DateTime.utc(2026, 8, 20 - i),
      ),
  ];

  late _MockNotesRepository repo;

  setUp(() {
    repo = _MockNotesRepository();
    when(() => repo.setPosition(any(), any())).thenAnswer((_) async {});
  });

  Future<void> pumpList(
    WidgetTester tester,
    List<Note> notes, {
    NotesViewOptions options = const NotesViewOptions(),
    bool routed = false,
    List<Note> archived = const [],
    List<Note> trashed = const [],
    PictureSearchRepository? pictureSearch,
    bool burnDeleted = true,
  }) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serverUrlProvider.overrideWithValue('https://example.test'),
          authControllerProvider.overrideWith(_SignedIn.new),
          notesRepositoryProvider.overrideWithValue(repo),
          notesProvider.overrideWith((ref) => Stream.value(notes)),
          archivedNotesProvider.overrideWith((ref) => Stream.value(archived)),
          trashedNotesProvider.overrideWith((ref) => Stream.value(trashed)),
          allActiveNotesProvider.overrideWith((ref) => Stream.value(notes)),
          tagsControllerProvider.overrideWith(_Tags.new),
          notesViewOptionsProvider.overrideWith(() => _ViewOptions(options)),
          reminderPermissionsControllerProvider.overrideWith(_Permissions.new),
          syncManagerProvider.overrideWith(_Sync.new),
          syncCompatibilityProvider.overrideWith(
            (ref) async => SyncCompatibility.ok,
          ),
          isOnlineProvider.overrideWith((ref) => true),
          firstDownloadProvider.overrideWithValue(FirstDownload.done),
          appBootstrapProvider.overrideWithValue(
            AppBootstrap(
              editorPreferences: EditorPreferences(burnDeleted: burnDeleted),
            ),
          ),
          if (pictureSearch != null)
            pictureSearchRepositoryProvider.overrideWithValue(pictureSearch),
          pictureSearchStatusProvider.overrideWith(
            (ref) async => PictureSearchStatus(
              available: true,
              enabled: pictureSearch != null,
            ),
          ),
        ],
        child: routed
            ? MaterialApp.router(
                theme: AppTheme.light(),
                routerConfig: GoRouter(
                  routes: [
                    GoRoute(
                      path: '/',
                      builder: (context, state) => const NotesListScreen(),
                    ),
                    GoRoute(
                      path: '/note/new',
                      builder: (context, state) => Text('Opened ${state.uri}'),
                    ),
                  ],
                ),
              )
            : MaterialApp(
                theme: AppTheme.light(),
                home: const NotesListScreen(),
              ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }

  Offset centre(WidgetTester tester, String title) =>
      tester.getCenter(find.text(title).first);

  Future<void> drag(WidgetTester tester, String from, String onto) async {
    final gesture = await tester.startGesture(centre(tester, from));
    await tester.pump(const Duration(milliseconds: 700));
    await gesture.moveTo(centre(tester, onto));
    await tester.pump(const Duration(milliseconds: 400));
    await gesture.moveBy(const Offset(1, 1));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
  }

  testWidgets('a held card follows the finger and the others make room', (
    tester,
  ) async {
    final notes = notesNamed('Note', 4);
    await pumpList(tester, notes);

    final first = tester.getTopLeft(find.text('Note 0'));
    // Note 3 (last) onto Note 0 (first).
    final gesture = await tester.startGesture(centre(tester, 'Note 3'));
    await tester.pump(const Duration(milliseconds: 700));
    await gesture.moveTo(centre(tester, 'Note 0'));
    await tester.pump(const Duration(milliseconds: 400));
    // The card in hand, above its open place.
    expect(find.text('Note 3'), findsNWidgets(2));
    await gesture.moveBy(const Offset(1, 1));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    // It takes the first place, held for a moment in case the list is slow
    // to follow.
    expect(tester.getTopLeft(find.text('Note 3')), first);
    await tester.pump(const Duration(seconds: 3));

    final captured = verify(
      () => repo.setPosition('Note3', captureAny()),
    ).captured;
    // Ahead of Note 0, the newest.
    expect(captured.single as double, greaterThan(noteSortKey(notes[0])));
  });

  testWidgets('a note dropped between two goes between them', (tester) async {
    final notes = notesNamed('Note', 4);
    await pumpList(
      tester,
      notes,
      options: const NotesViewOptions(viewType: ViewType.list),
    );

    // Note 0 onto Note 2: it lands between Note 2 and Note 3.
    await drag(tester, 'Note 0', 'Note 2');
    await tester.pump(const Duration(seconds: 3));

    final captured = verify(
      () => repo.setPosition('Note0', captureAny()),
    ).captured;
    expect(
      captured.single as double,
      (noteSortKey(notes[2]) + noteSortKey(notes[3])) / 2,
    );
  });

  testWidgets('holding a card without moving selects it', (tester) async {
    await pumpList(tester, notesNamed('Note', 3));

    final gesture = await tester.startGesture(centre(tester, 'Note 1'));
    await tester.pump(const Duration(milliseconds: 700));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('1 selected'), findsOneWidget);
    verifyNever(() => repo.setPosition(any(), any()));
  });

  testWidgets('an item ticked from a card keeps the note in its place', (
    tester,
  ) async {
    when(
      () => repo.changeContent(any(), any(), keepAt: any(named: 'keepAt')),
    ).thenAnswer((_) async {});
    final note = Note(
      id: 'list',
      title: 'Shopping',
      content:
          '{"ops":[{"insert":"milk"},{"insert":"\\n","attributes":{"list":"unchecked"}}]}',
      updatedAt: DateTime.utc(2026, 8, 18),
    );
    await pumpList(tester, [...notesNamed('Note', 1), note]);

    final item = find.text('milk', findRichText: true);
    await tester.tapAt(
      tester.getCenter(item) - Offset(tester.getSize(item).width / 2 + 10, 0),
    );
    await tester.pump();

    final kept = verify(
      () => repo.changeContent(
        'list',
        any(),
        keepAt: captureAny(named: 'keepAt'),
      ),
    ).captured.single;
    expect(kept, keptPlace(note));
  });

  group('deleting', () {
    Finder burning() => find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is BurnPainter,
    );

    Future<void> deleteSelected(
      WidgetTester tester,
      String title, {
      String action = 'Delete',
    }) async {
      final gesture = await tester.startGesture(centre(tester, title));
      await tester.pump(const Duration(milliseconds: 700));
      await gesture.up();
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel(action));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }

    testWidgets('a deleted card burns where it stands, then goes', (
      tester,
    ) async {
      when(() => repo.trash(any())).thenAnswer((_) async {});
      await pumpList(tester, notesNamed('Note', 3));
      final nextBefore = tester.getTopLeft(find.text('Note 2'));

      await deleteSelected(tester, 'Note 1');
      await tester.pump(destructionDuration ~/ 2);
      // Burning in place: the cards after it stay put meanwhile.
      expect(burning(), findsOneWidget);
      expect(tester.getTopLeft(find.text('Note 2')), nextBefore);
      verifyNever(() => repo.trash(any()));

      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      verify(() => repo.trash(['Note1'])).called(1);
      await tester.pump(const Duration(seconds: 7));
    });

    testWidgets('deleting forever lets the dialog close, then burns', (
      tester,
    ) async {
      when(() => repo.deleteForever(any())).thenAnswer((_) async {});
      final trashed = [
        for (final note in notesNamed('Note', 2))
          note.copyWith(state: NoteState.trashed),
      ];
      await pumpList(tester, const [], trashed: trashed);
      ProviderScope.containerOf(
        tester.element(find.byType(NotesListScreen)),
      ).read(noteFolderProvider.notifier).go(NoteFolder.trash);
      await tester.pumpAndSettle();

      await deleteSelected(tester, 'Note 1', action: 'Delete permanently');
      await tester.pumpAndSettle();
      expect(find.text('Permanently delete this note?'), findsOneWidget);
      await tester.tap(find.text('Delete permanently').last);
      await tester.pump();
      // The dialog closes first.
      expect(burning(), findsNothing);
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Permanently delete this note?'), findsNothing);
      expect(burning(), findsOneWidget);
      verifyNever(() => repo.deleteForever(any()));

      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      verify(() => repo.deleteForever(['Note1'])).called(1);
      await tester.pump(const Duration(seconds: 7));
    });

    testWidgets('if deleting fails, the card comes back', (tester) async {
      when(() => repo.trash(any())).thenThrow(Exception('disk full'));
      await pumpList(tester, notesNamed('Note', 3));

      await deleteSelected(tester, 'Note 1');
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(burning(), findsNothing);
      final fade = tester.widget<AnimatedOpacity>(
        find
            .ancestor(
              of: find.text('Note 1'),
              matching: find.byType(AnimatedOpacity),
            )
            .first,
      );
      expect(fade.opacity, 1);
      expect(
        find.textContaining('Couldn’t delete the note', findRichText: true),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('with Burn deleted notes off, the card just goes', (
      tester,
    ) async {
      when(() => repo.trash(any())).thenAnswer((_) async {});
      await pumpList(tester, notesNamed('Note', 3), burnDeleted: false);

      await deleteSelected(tester, 'Note 1');

      expect(burning(), findsNothing);
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      verify(() => repo.trash(['Note1'])).called(1);
      await tester.pump(const Duration(seconds: 7));
    });

    testWidgets('with reduced motion nothing burns', (tester) async {
      when(() => repo.trash(any())).thenAnswer((_) async {});
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await pumpList(tester, notesNamed('Note', 3));

      await deleteSelected(tester, 'Note 1');

      expect(burning(), findsNothing);
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      verify(() => repo.trash(['Note1'])).called(1);
      await tester.pump(const Duration(seconds: 7));
    });
  });

  testWidgets('sorted by title, a hold selects and nothing drags', (
    tester,
  ) async {
    await pumpList(
      tester,
      notesNamed('Note', 3),
      options: const NotesViewOptions(sortOption: SortOption.title),
    );

    await drag(tester, 'Note 2', 'Note 0');

    expect(find.text('1 selected'), findsOneWidget);
    verifyNever(() => repo.setPosition(any(), any()));
  });

  testWidgets('Select notes starts selecting without a hold', (tester) async {
    await pumpList(tester, notesNamed('Note', 3));

    await tester.tap(find.bySemanticsLabel('Select notes'));
    await tester.pumpAndSettle();
    expect(find.text('Select notes'), findsOneWidget);
    await tester.tap(find.text('Note 2'));
    await tester.pumpAndSettle();

    expect(find.text('1 selected'), findsOneWidget);
  });

  group('picking after Select notes', () {
    List<String> picked(WidgetTester tester) => [
      for (final card in tester.widgetList<NoteCard>(find.byType(NoteCard)))
        if (card.isSelected) card.note.title,
    ];

    testWidgets('a tap picks a card in every section', (tester) async {
      await pumpList(tester, [
        const Note(id: 'p', title: 'Pinned one', isPinned: true),
        ...notesNamed('Note', 3),
      ]);
      await tester.tap(find.bySemanticsLabel('Select notes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pinned one'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Note 2'));
      await tester.pumpAndSettle();

      expect(find.text('2 selected'), findsOneWidget);
      expect(picked(tester), ['Pinned one', 'Note 2']);
    });

    testWidgets('after scrolling a long list a tap still picks, and Select '
        'all marks every card', (tester) async {
      await pumpList(tester, notesNamed('Note', 30));
      await tester.drag(
        find.byType(CustomScrollView).first,
        const Offset(0, -900),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Select notes'));
      await tester.pumpAndSettle();
      final shown = find
          .textContaining(RegExp(r'^Note \d+$'))
          .hitTestable()
          .first;
      final title = tester.widget<Text>(shown).data;
      await tester.tap(shown);
      await tester.pumpAndSettle();
      expect(find.text('1 selected'), findsOneWidget);
      expect(picked(tester), [title]);

      await tester.tap(find.bySemanticsLabel('Select all'));
      await tester.pumpAndSettle();
      expect(find.text('30 selected'), findsOneWidget);
      final cards = tester.widgetList<NoteCard>(find.byType(NoteCard));
      expect(cards, isNotEmpty);
      expect(cards.every((card) => card.isSelected), isTrue);
    });

    testWidgets('a tap on a card\'s picture picks the card', (tester) async {
      await pumpList(tester, [
        const Note(
          id: 'pic',
          title: 'With a picture',
          attachmentCount: 1,
          imagePreviewData: [
            NoteImagePreview(
              attachmentId: 'a1',
              noteId: 'pic',
              filename: 'a.jpg',
            ),
          ],
        ),
        ...notesNamed('Note', 2),
      ]);
      await tester.tap(find.bySemanticsLabel('Select notes'));
      await tester.pump(const Duration(milliseconds: 500));
      final card = find.ancestor(
        of: find.text('With a picture'),
        matching: find.byType(NoteCard),
      );
      // The top of the card, where the picture is.
      final spot = tester.getTopLeft(card) + const Offset(40, 20);
      expect(
        tester
            .getRect(
              find
                  .descendant(
                    of: card,
                    matching: find.byWidgetPredicate(
                      (w) => '${w.runtimeType}' == '_Thumbnail',
                    ),
                  )
                  .first,
            )
            .contains(spot),
        isTrue,
      );
      await tester.tapAt(spot);
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('1 selected'), findsOneWidget);
      expect(find.byType(PageView), findsNothing);
    });
  });

  testWidgets('a search also lists notes whose pictures look like it', (
    tester,
  ) async {
    final pictureSearch = _MockPictureSearchRepository();
    when(
      () => pictureSearch.search('Katze'),
    ).thenAnswer((_) async => ['cats', 'kitten', 'old-cat']);
    await pumpList(
      tester,
      const [
        Note(id: 'cats', title: 'Holiday'),
        Note(id: 'kitten', title: 'Katze Mimi'),
        Note(id: 'dog', title: 'Walks'),
      ],
      archived: const [
        Note(id: 'old-cat', title: 'Last year', isArchived: true),
      ],
      pictureSearch: pictureSearch,
    );

    await tester.tap(find.bySemanticsLabel('Search notes'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Katze');
    await tester.pump();
    // The server is asked once typing pauses.
    await tester.pump(pictureSearchPause);
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Pictures that may match, 2'), findsOneWidget);
    expect(find.text('Holiday'), findsOneWidget);
    expect(find.text('Last year'), findsOneWidget);
    // Found by its text already: listed once.
    expect(find.text('Katze Mimi'), findsOneWidget);
    expect(find.text('Walks'), findsNothing);
  });

  testWidgets('with picture search off, only words find notes', (tester) async {
    await pumpList(tester, const [Note(id: 'cats', title: 'Holiday')]);

    await tester.tap(find.bySemanticsLabel('Search notes'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Katze');
    await tester.pump(pictureSearchPause);
    await tester.pumpAndSettle();

    expect(find.text('Holiday'), findsNothing);
    expect(find.textContaining('PICTURES'), findsNothing);
  });

  testWidgets('a search started from a picture tag shows its results', (
    tester,
  ) async {
    await pumpList(tester, const [
      Note(id: 'boats', title: 'Boot trip'),
      Note(id: 'dog', title: 'Walks'),
    ]);

    ProviderScope.containerOf(
      tester.element(find.byType(NotesListScreen)),
    ).read(searchQueryProvider.notifier).set('Boot');
    await tester.pumpAndSettle();

    expect(find.text('Walks'), findsNothing);
    expect(find.text('Boot trip'), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, 'Boot');
    // The results, not the keyboard.
    expect(field.focusNode!.hasFocus, isFalse);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Walks'), findsOneWidget);
  });

  testWidgets('holding New note offers a new list', (tester) async {
    await pumpList(tester, notesNamed('Note', 2));

    await tester.longPress(find.bySemanticsLabel('New note'));
    await tester.pumpAndSettle();

    expect(find.text('New list'), findsOneWidget);
    expect(find.text('New note'), findsOneWidget);
  });

  group('New note with text on the clipboard', () {
    void setClipboard(WidgetTester tester, {required bool hasText}) {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async =>
            call.method == 'Clipboard.hasStrings' ? {'value': hasText} : null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
    }

    testWidgets('a double tap opens a new note with it pasted in', (
      tester,
    ) async {
      setClipboard(tester, hasText: true);
      await pumpList(tester, notesNamed('Note', 2), routed: true);

      await tester.tap(find.bySemanticsLabel('New note'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.bySemanticsLabel('New note'));
      await tester.pumpAndSettle();

      expect(find.text('Opened /note/new?paste=1'), findsOneWidget);
    });

    testWidgets('a single tap still opens an empty note', (tester) async {
      setClipboard(tester, hasText: true);
      await pumpList(tester, notesNamed('Note', 2), routed: true);

      await tester.tap(find.bySemanticsLabel('New note'));
      await tester.pump(kDoubleTapTimeout);
      await tester.pumpAndSettle();

      expect(find.text('Opened /note/new'), findsOneWidget);
    });

    testWidgets('with nothing to paste, a tap opens a note at once', (
      tester,
    ) async {
      setClipboard(tester, hasText: false);
      await pumpList(tester, notesNamed('Note', 2), routed: true);

      await tester.tap(find.bySemanticsLabel('New note'));
      // Well before a second tap could come.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Opened /note/new'), findsOneWidget);
    });
  });
}

class _SignedIn extends AuthController {
  @override
  Future<User?> build() async =>
      const User(id: 'u1', email: 'oliver@example.com', name: 'Oliver Grant');
}

class _Tags extends TagsController {
  @override
  Stream<List<Tag>> build() => Stream.value(const []);
}

class _ViewOptions extends NotesViewOptionsNotifier {
  _ViewOptions(this.options);

  final NotesViewOptions options;

  @override
  Future<NotesViewOptions> build() async => options;
}

class _Permissions extends ReminderPermissionsController {
  @override
  Future<ReminderPermissions> build() async => const ReminderPermissions(
    canNotify: true,
    canBeExact: true,
    needsExactAlarmPermission: false,
  );
}

class _Sync extends SyncManager {
  @override
  bool build() => false;

  @override
  Future<bool> requestSync() async => false;
}
