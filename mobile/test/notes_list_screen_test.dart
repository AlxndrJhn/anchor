import 'dart:async';

import 'package:anchor/core/network/connectivity_provider.dart';
import 'package:anchor/core/network/server_config_provider.dart';
import 'package:anchor/core/notifications/notification_gateway.dart';
import 'package:anchor/core/providers/active_user_id_provider.dart';
import 'package:anchor/features/notes/data/repository/notes_repository.dart';
import 'package:anchor/features/notes/domain/note.dart';
import 'package:anchor/features/notes/presentation/notes_list_screen.dart';
import 'package:anchor/features/notes/presentation/notes_view_options.dart';
import 'package:anchor/features/picture_search/picture_search.dart';
import 'package:anchor/features/settings/data/repository/preferences_repository.dart';
import 'package:anchor/features/settings/presentation/controllers/editor_preferences_controller.dart';
import 'package:anchor/features/sync/data/sync_compatibility.dart';
import 'package:anchor/features/tags/data/repository/tags_repository.dart';
import 'package:anchor/features/tags/domain/tag.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/gestures.dart' show kDoubleTapTimeout;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mocktail/mocktail.dart';

import 'reminder_permissions_test.dart' show FakeGateway;

class MockNotesRepository extends Mock implements NotesRepository {}

class MockTagsRepository extends Mock implements TagsRepository {}

class MockPreferencesRepository extends Mock implements PreferencesRepository {}

class FakeActiveUserId extends ActiveUserId {
  @override
  String? build() => 'user-1';
}

class FakeSyncManager extends SyncManager {
  @override
  bool build() => false;
}

class MockPictureSearchRepository extends Mock
    implements PictureSearchRepository {}

class GridViewOptions extends NotesViewOptionsNotifier {
  @override
  Future<NotesViewOptions> build() async => const NotesViewOptions();
}

String checklist(int lines) =>
    '{"ops":[${List.generate(lines, (i) => '{"insert":"item $i"},{"insert":"\\n","attributes":{"list":"unchecked"}}').join(',')}]}';

void main() {
  late MockNotesRepository notesRepo;
  late MockTagsRepository tagsRepo;
  late MockPreferencesRepository prefsRepo;

  setUpAll(() => registerFallbackValue(const Note(id: 'fallback', title: '')));

  setUp(() {
    notesRepo = MockNotesRepository();
    tagsRepo = MockTagsRepository();
    prefsRepo = MockPreferencesRepository();
    when(
      () => tagsRepo.watchTags(),
    ).thenAnswer((_) => Stream.value(const <Tag>[]));
    when(() => prefsRepo.getExactAlarmsOffered()).thenAnswer((_) async => true);
  });

  Future<void> pumpList(
    WidgetTester tester,
    List<Note> notes, {
    List<Note> archived = const [],
    PictureSearchRepository? pictureSearch,
    // A card's picture shimmers while it loads, and never settles.
    bool settle = true,
  }) async {
    when(
      () => notesRepo.watchNotes(tagId: any(named: 'tagId')),
    ).thenAnswer((_) => Stream.value(notes));
    when(
      () => notesRepo.watchArchivedNotes(),
    ).thenAnswer((_) => Stream.value(archived));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notesRepositoryProvider.overrideWithValue(notesRepo),
          tagsRepositoryProvider.overrideWithValue(tagsRepo),
          preferencesRepositoryProvider.overrideWithValue(prefsRepo),
          serverUrlProvider.overrideWith((ref) => null),
          connectivityStreamProvider.overrideWith(
            (ref) => const Stream<List<ConnectivityResult>>.empty(),
          ),
          activeUserIdProvider.overrideWith(FakeActiveUserId.new),
          notificationGatewayProvider.overrideWithValue(FakeGateway()),
          syncManagerProvider.overrideWith(FakeSyncManager.new),
          syncCompatibilityProvider.overrideWith(
            (ref) => Completer<SyncCompatibility>().future,
          ),
          notesViewOptionsProvider.overrideWith(GridViewOptions.new),
          if (pictureSearch != null)
            pictureSearchRepositoryProvider.overrideWithValue(pictureSearch),
          pictureSearchStatusProvider.overrideWith(
            (ref) async => PictureSearchStatus(
              available: true,
              enabled: pictureSearch != null,
            ),
          ),
        ],
        child: MaterialApp.router(
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
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump(const Duration(milliseconds: 500));
    }
  }

  Future<void> scrollToEnd(WidgetTester tester) async {
    for (var i = 0; i < 25; i++) {
      await tester.drag(
        find.byType(CustomScrollView).first,
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();
    }
  }

  ScrollPosition listPosition(WidgetTester tester) =>
      tester.state<ScrollableState>(find.byType(Scrollable).first).position;

  List<Note> notesNamed(String prefix, int count, {int pinned = 0}) => [
    for (var i = 0; i < count; i++)
      Note(
        id: '$prefix$i',
        title: '$prefix $i',
        content: checklist(2 + i % 5),
        isPinned: i < pinned,
        updatedAt: DateTime.utc(2026, 1, 30 - i),
      ),
  ];

  // Two lazy masonry grids in one list kept correcting each other's height
  // and bounced the list back before its end.
  testWidgets('scrolls to the last note below the pinned ones', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await pumpList(tester, notesNamed('Note', 15, pinned: 3));

    await scrollToEnd(tester);

    final position = listPosition(tester);
    expect(position.pixels, position.maxScrollExtent);
    expect(find.text('Note 14'), findsOneWidget);
  });

  testWidgets('two screens down, a chevron goes back to the top', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await pumpList(tester, notesNamed('Note', 40));
    final toTop = find.byTooltip('Back to top');
    double shown() => tester
        .widget<AnimatedScale>(
          find.ancestor(of: toTop, matching: find.byType(AnimatedScale)),
        )
        .scale;
    expect(shown(), 0);

    await scrollToEnd(tester);
    expect(listPosition(tester).pixels, greaterThan(2340 / 3 * 2));
    expect(shown(), 1);

    await tester.tap(toTop);
    await tester.pumpAndSettle();
    expect(listPosition(tester).pixels, 0);
    expect(shown(), 0);
  });

  testWidgets('scrolls to the last archived search result', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await pumpList(
      tester,
      notesNamed('Note', 12, pinned: 2),
      archived: notesNamed('Old', 6),
    );
    await tester.enterText(find.byType(TextField), 'item');
    await tester.pumpAndSettle();

    await scrollToEnd(tester);

    final position = listPosition(tester);
    expect(position.pixels, position.maxScrollExtent);
    expect(find.text('Old 5'), findsOneWidget);
  });

  testWidgets('a search also lists notes whose pictures look like it', (
    tester,
  ) async {
    final pictureSearch = MockPictureSearchRepository();
    when(
      () => pictureSearch.search('katze'),
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

    await tester.enterText(find.byType(TextField), 'Katze');
    await tester.pump();
    // The server is asked once typing pauses.
    await tester.pump(pictureSearchPause);
    await tester.pumpAndSettle();

    expect(find.text('PICTURES THAT MAY MATCH  2'), findsOneWidget);
    expect(find.text('Holiday'), findsOneWidget);
    expect(find.text('Last year'), findsOneWidget);
    // Found by its text already: listed once.
    expect(find.text('Katze Mimi'), findsOneWidget);
    expect(find.text('Walks'), findsNothing);
  });

  group('dragging notes', () {
    setUp(() {
      when(() => notesRepo.setPosition(any(), any())).thenAnswer((_) async {});
    });

    Offset centre(WidgetTester tester, String title) =>
        tester.getCenter(find.text(title).first);

    testWidgets('a held card follows the finger and the others make room', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final notes = notesNamed('Note', 4);
      await pumpList(tester, notes);

      // Note 3 (last) onto Note 0 (first).
      final gesture = await tester.startGesture(centre(tester, 'Note 3'));
      await tester.pump(const Duration(milliseconds: 700));
      await gesture.moveTo(centre(tester, 'Note 0'));
      await tester.pump(const Duration(milliseconds: 400));
      await gesture.moveBy(const Offset(1, 1));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      // The order is held for a moment in case the list is slow to follow.
      await tester.pump(const Duration(seconds: 3));

      final captured = verify(
        () => notesRepo.setPosition('Note3', captureAny()),
      ).captured;
      // Ahead of Note 0, the newest.
      expect(captured.single as double, greaterThan(noteSortKey(notes[0])));
    });

    testWidgets('holding a card without moving selects it', (tester) async {
      await pumpList(tester, notesNamed('Note', 3));

      final gesture = await tester.startGesture(centre(tester, 'Note 1'));
      await tester.pump(const Duration(milliseconds: 700));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.text('1 note'), findsOneWidget);
      verifyNever(() => notesRepo.setPosition(any(), any()));
    });

    testWidgets('Select notes starts selecting without a long press', (
      tester,
    ) async {
      await pumpList(tester, notesNamed('Note', 3));

      await tester.tap(find.byTooltip('Select notes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Note 2'));
      await tester.pumpAndSettle();

      expect(find.text('1 note'), findsOneWidget);
    });
  });

  group('selecting after Select notes', () {
    Finder ticks() => find.byIcon(LucideIcons.check);

    testWidgets('a tap anywhere on a card picks it, in every section', (
      tester,
    ) async {
      await pumpList(tester, notesNamed('Note', 4, pinned: 1));

      await tester.tap(find.byTooltip('Select notes'));
      await tester.pumpAndSettle();
      // The pinned one, and another below, tapped on their text.
      await tester.tap(find.text('item 0').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Note 2'));
      await tester.pumpAndSettle();

      expect(find.text('2 notes'), findsOneWidget);
      expect(ticks(), findsNWidgets(2));
    });

    testWidgets('after scrolling a long list, a tap still picks', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await pumpList(tester, notesNamed('Note', 30, pinned: 2));
      await tester.drag(
        find.byType(CustomScrollView).first,
        const Offset(0, -900),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Select notes'));
      await tester.pumpAndSettle();
      final visible = find.textContaining(RegExp(r'^Note \d+$')).hitTestable();
      await tester.tap(visible.first);
      await tester.pumpAndSettle();

      expect(find.text('1 note'), findsOneWidget);
      await tester.tap(find.byTooltip('Select all'));
      await tester.pumpAndSettle();
      expect(find.text('30 notes'), findsOneWidget);
      expect(find.byIcon(LucideIcons.check).hitTestable(), findsWidgets);
    });

    testWidgets('a tap on a picked card\'s picture picks it, not opens it', (
      tester,
    ) async {
      await pumpList(tester, [
        const Note(
          id: 'pic',
          title: 'With a picture',
          imagePreviewData: [
            NoteImagePreview(
              attachmentId: 'a1',
              noteId: 'pic',
              filename: 'a.jpg',
            ),
          ],
        ),
        ...notesNamed('Note', 2),
      ], settle: false);

      await tester.tap(find.byTooltip('Select notes'));
      await tester.pump(const Duration(milliseconds: 500));
      final card = find.ancestor(
        of: find.text('With a picture'),
        matching: find.byType(Card),
      );
      // The top of the card, where the picture is.
      await tester.tapAt(tester.getTopLeft(card) + const Offset(40, 20));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('1 note'), findsOneWidget);
    });

    testWidgets('More › Merge notes merges into the first picked, with Undo', (
      tester,
    ) async {
      final notes = notesNamed('Note', 3);
      when(() => notesRepo.updateNote(any())).thenAnswer((_) async {});
      when(() => notesRepo.bulkDeleteNotes(any())).thenAnswer((_) async => 1);
      when(() => notesRepo.restoreNote(any())).thenAnswer((_) async {});
      await pumpList(tester, notes);

      await tester.tap(find.byTooltip('Select notes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Note 2'));
      await tester.tap(find.text('Note 0'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Merge notes'));
      await tester.pumpAndSettle();

      final merged =
          verify(() => notesRepo.updateNote(captureAny())).captured.single
              as Note;
      expect(merged.id, 'Note2');
      expect(merged.content, contains('Note 0'));
      verify(() => notesRepo.bulkDeleteNotes(['Note0'])).called(1);
      expect(find.text('Merged 2 notes'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      verify(() => notesRepo.updateNote(notes[2])).called(1);
      verify(() => notesRepo.restoreNote('Note0')).called(1);
    });

    testWidgets('Select all marks every card', (tester) async {
      await pumpList(tester, notesNamed('Note', 3, pinned: 1));

      await tester.tap(find.byTooltip('Select notes'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Select all'));
      await tester.pumpAndSettle();

      expect(find.text('3 notes'), findsOneWidget);
      expect(ticks(), findsNWidgets(3));
    });
  });

  testWidgets('holding New Note offers a new list', (tester) async {
    await pumpList(tester, notesNamed('Note', 2));

    await tester.longPress(find.text('New Note'));
    await tester.pumpAndSettle();

    expect(find.text('New list'), findsOneWidget);
    expect(find.text('Camera note'), findsOneWidget);
    expect(find.text('New note'), findsOneWidget);
  });

  group('New Note with text on the clipboard', () {
    Future<void> setClipboard(
      WidgetTester tester, {
      required bool hasText,
    }) async {
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
      await setClipboard(tester, hasText: true);
      await pumpList(tester, notesNamed('Note', 2));

      await tester.tap(find.text('New Note'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('New Note'));
      await tester.pumpAndSettle();

      expect(find.text('Opened /note/new?paste=1'), findsOneWidget);
    });

    testWidgets('a single tap still opens an empty note', (tester) async {
      await setClipboard(tester, hasText: true);
      await pumpList(tester, notesNamed('Note', 2));

      await tester.tap(find.text('New Note'));
      await tester.pump(kDoubleTapTimeout);
      await tester.pumpAndSettle();

      expect(find.text('Opened /note/new'), findsOneWidget);
    });

    testWidgets('with nothing to paste, a tap opens a note at once', (
      tester,
    ) async {
      await setClipboard(tester, hasText: false);
      await pumpList(tester, notesNamed('Note', 2));

      await tester.tap(find.text('New Note'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Opened /note/new'), findsOneWidget);
    });
  });
}
