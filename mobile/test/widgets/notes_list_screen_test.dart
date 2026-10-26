import 'package:anchor/core/network/connectivity_provider.dart';
import 'package:anchor/core/network/server_config_provider.dart';
import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/features/auth/domain/user.dart';
import 'package:anchor/features/auth/presentation/auth_controller.dart';
import 'package:anchor/features/notes/data/repository/notes_repository.dart';
import 'package:anchor/features/notes/domain/note.dart';
import 'package:anchor/features/notes/presentation/notes_controller.dart';
import 'package:anchor/features/notes/presentation/notes_list_screen.dart';
import 'package:anchor/features/notes/presentation/notes_view_options.dart';
import 'package:anchor/features/reminders/data/reminder_permissions.dart';
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
          archivedNotesProvider.overrideWith((ref) => Stream.value([])),
          trashedNotesProvider.overrideWith((ref) => Stream.value([])),
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
