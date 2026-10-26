import 'dart:async';

import 'package:anchor/core/network/connectivity_provider.dart';
import 'package:anchor/core/network/server_config_provider.dart';
import 'package:anchor/core/notifications/notification_gateway.dart';
import 'package:anchor/core/providers/active_user_id_provider.dart';
import 'package:anchor/features/notes/data/repository/notes_repository.dart';
import 'package:anchor/features/notes/domain/note.dart';
import 'package:anchor/features/notes/presentation/notes_list_screen.dart';
import 'package:anchor/features/notes/presentation/notes_view_options.dart';
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
    await tester.pumpAndSettle();
  }

  Future<void> scrollToEnd(WidgetTester tester) async {
    for (var i = 0; i < 25; i++) {
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
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

  testWidgets('holding New Note offers a new list', (tester) async {
    await pumpList(tester, notesNamed('Note', 2));

    await tester.longPress(find.text('New Note'));
    await tester.pumpAndSettle();

    expect(find.text('New list'), findsOneWidget);
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
