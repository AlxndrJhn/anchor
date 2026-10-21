import 'dart:async';
import 'dart:convert';

import 'package:anchor/core/network/connectivity_provider.dart';
import 'package:anchor/core/session/active_user_id_provider.dart';
import 'package:anchor/features/notes/data/repository/note_history_repository.dart';
import 'package:anchor/features/notes/data/repository/note_revisions_store.dart';
import 'package:anchor/features/notes/data/repository/notes_repository.dart';
import 'package:anchor/features/notes/domain/note.dart';
import 'package:anchor/features/notes/domain/note_revision.dart';
import 'package:anchor/features/notes/presentation/note_history_screen.dart';
import 'package:anchor/features/notes/presentation/note_revision_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mocktail/mocktail.dart';

class MockNotesRepository extends Mock implements NotesRepository {}

class MockNoteHistoryRepository extends Mock implements NoteHistoryRepository {}

class MockNoteRevisionsStore extends Mock implements NoteRevisionsStore {}

class FakeActiveUserId extends ActiveUserId {
  @override
  String? build() => 'user-1';
}

class FakeNoteRevision extends Fake implements NoteRevision {}

const offlineMessage =
    'Connect to the internet to see versions from your other devices.';

/// The phone's time format, with its narrow space before AM.
final tenThirty = DateFormat.jm('en').format(DateTime(2026, 1, 1, 10, 30));

const failedMessage = 'Couldn’t check for versions from your other devices.';

String delta(List<String> lines) => jsonEncode({
  'ops': [
    {'insert': '${lines.join('\n')}\n'},
  ],
});

NoteRevision revisionOf({
  required String id,
  required DateTime createdAt,
  String title = 'Groceries',
  String? content,
  RevisionCause cause = RevisionCause.edit,
}) => NoteRevision(
  id: id,
  noteId: 'n1',
  version: 1,
  title: title,
  cause: cause,
  createdAt: createdAt,
  content: content,
);

void main() {
  late MockNotesRepository notesRepo;
  late MockNoteHistoryRepository historyRepo;
  late MockNoteRevisionsStore store;

  // The list labels days against the day it runs on.
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  final note = Note(
    id: 'n1',
    title: 'Groceries',
    content: delta(['milk', 'eggs']),
    updatedAt: today.add(const Duration(hours: 12)),
  );

  final stored = [
    revisionOf(
      id: 'r2',
      createdAt: today.add(const Duration(hours: 10, minutes: 30)),
      content: delta(['milk', 'bread']),
    ),
    revisionOf(
      id: 'r1',
      createdAt: today.subtract(const Duration(hours: 15)),
      content: delta(['milk']),
    ),
  ];

  setUpAll(() => registerFallbackValue(FakeNoteRevision()));

  setUp(() {
    notesRepo = MockNotesRepository();
    historyRepo = MockNoteHistoryRepository();
    store = MockNoteRevisionsStore();

    when(
      () => notesRepo.watchNote(any()),
    ).thenAnswer((_) => Stream.value(note));
    when(() => notesRepo.restoreVersion(any(), any())).thenAnswer((_) async {});
    when(() => store.watch(any())).thenAnswer((_) => Stream.value(stored));
    when(() => store.watchPosition(any())).thenAnswer(
      (_) => Stream.value(
        const NoteHistoryPosition(cursor: 'older', isRead: true),
      ),
    );
    when(() => store.markStale(any())).thenAnswer((_) async {});
    when(() => historyRepo.fetch(any())).thenAnswer((_) async {});
  });

  Future<void> pumpScreen(WidgetTester tester, {bool isOnline = true}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notesRepositoryProvider.overrideWithValue(notesRepo),
          noteHistoryRepositoryProvider.overrideWithValue(historyRepo),
          noteRevisionsStoreProvider.overrideWithValue(store),
          activeUserIdProvider.overrideWith(FakeActiveUserId.new),
          isOnlineProvider.overrideWithValue(isOnline),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: '/note/n1/history',
            routes: [
              GoRoute(
                path: '/note/:id',
                builder: (_, _) =>
                    const Scaffold(body: Center(child: Text('Editor'))),
                routes: [
                  GoRoute(
                    path: 'history',
                    builder: (_, state) =>
                        NoteHistoryScreen(noteId: state.pathParameters['id']!),
                    routes: [
                      GoRoute(
                        path: ':revisionId',
                        builder: (_, state) => NoteRevisionScreen(
                          noteId: state.pathParameters['id']!,
                          revisionId: state.pathParameters['revisionId']!,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lists the versions by day above the note as it is now', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text('Current version'), findsOneWidget);
    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text('YESTERDAY'), findsOneWidget);
    expect(find.text(tenThirty), findsOneWidget);
  });

  testWidgets('versions of one day are split by a line where the text starts', (
    tester,
  ) async {
    when(() => store.watch(any())).thenAnswer(
      (_) => Stream.value([
        revisionOf(
          id: 'r3',
          createdAt: today.add(const Duration(hours: 11)),
          content: delta(['milk', 'bread', 'eggs']),
        ),
        ...stored,
      ]),
    );
    await pumpScreen(tester);

    final lines = find.byWidgetPredicate(
      (widget) => widget is PositionedDirectional && widget.start == 56,
    );
    expect(lines, findsOneWidget);
  });

  testWidgets('reads a version with no connection at all', (tester) async {
    await pumpScreen(tester, isOnline: false);
    await tester.tap(find.text(tenThirty));
    await tester.pumpAndSettle();

    expect(find.text('Today at $tenThirty'), findsOneWidget);
    expect(find.text('bread', findRichText: true), findsOneWidget);
    expect(find.text('eggs', findRichText: true), findsOneWidget);
    expect(find.text('Restore'), findsOneWidget);
    verifyNever(() => historyRepo.fetch(any()));
  });

  testWidgets('opening a version leaves the list to come back to', (
    tester,
  ) async {
    await pumpScreen(tester);
    await tester.tap(find.text(tenThirty));
    await tester.pumpAndSettle();

    expect(find.text('Today at $tenThirty'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Back to the version list'));
    await tester.pumpAndSettle();

    expect(find.byType(NoteRevisionScreen), findsNothing);
    expect(find.text('Version history'), findsWidgets);
    expect(find.text(tenThirty), findsOneWidget);
  });

  testWidgets('the note as it is now opens on its own page', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.text('Current version'));
    await tester.pumpAndSettle();

    expect(find.byType(NoteRevisionScreen), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(NoteRevisionScreen),
        matching: find.text('Current version'),
      ),
      findsOneWidget,
    );
    expect(find.text('1 of 3'), findsOneWidget);
    expect(find.text('Restore'), findsNothing);
  });

  testWidgets('puts a version back without waiting for the server', (
    tester,
  ) async {
    await pumpScreen(tester, isOnline: false);
    await tester.tap(find.text(tenThirty));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();

    final restored =
        verify(
              () => notesRepo.restoreVersion('n1', captureAny()),
            ).captured.single
            as NoteRevision;
    expect(restored.id, 'r2');

    expect(find.text('Editor'), findsOneWidget);
  });

  testWidgets('says versions kept elsewhere wait for a connection', (
    tester,
  ) async {
    await pumpScreen(tester, isOnline: false);

    expect(find.text(tenThirty), findsOneWidget);
    expect(find.text(offlineMessage), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
  });

  testWidgets('says so when versions kept elsewhere could not be read', (
    tester,
  ) async {
    when(() => historyRepo.fetch(any())).thenThrow(Exception('offline'));

    await pumpScreen(tester);

    expect(find.text(tenThirty), findsOneWidget);
    expect(find.text(failedMessage), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('trying again after a failed read asks the server once more', (
    tester,
  ) async {
    when(() => historyRepo.fetch(any())).thenThrow(Exception('offline'));
    await pumpScreen(tester);
    verify(() => historyRepo.fetch('n1')).called(1);
    expect(find.text('Try again'), findsOneWidget);

    when(() => historyRepo.fetch(any())).thenAnswer((_) async {});
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Try again'), findsNothing);
    verify(() => store.markStale('n1')).called(1);
    verify(() => historyRepo.fetch('n1')).called(1);
  });

  testWidgets('coming back online reads what the offline open could not', (
    tester,
  ) async {
    Future<void> pumpOnline({required bool isOnline}) => tester.pumpWidget(
      ProviderScope(
        overrides: [
          notesRepositoryProvider.overrideWithValue(notesRepo),
          noteHistoryRepositoryProvider.overrideWithValue(historyRepo),
          noteRevisionsStoreProvider.overrideWithValue(store),
          activeUserIdProvider.overrideWith(FakeActiveUserId.new),
          isOnlineProvider.overrideWithValue(isOnline),
        ],
        child: const MaterialApp(home: NoteHistoryScreen(noteId: 'n1')),
      ),
    );

    await pumpOnline(isOnline: false);
    await tester.pumpAndSettle();

    expect(find.text(offlineMessage), findsOneWidget);
    verifyNever(() => historyRepo.fetch(any()));

    await pumpOnline(isOnline: true);
    await tester.pumpAndSettle();

    expect(find.text(offlineMessage), findsNothing);
    verify(() => historyRepo.fetch('n1')).called(1);
  });

  testWidgets('asks for nothing once the whole history is here', (
    tester,
  ) async {
    when(
      () => store.watchPosition(any()),
    ).thenAnswer((_) => Stream.value(const NoteHistoryPosition(isRead: true)));

    await pumpScreen(tester);

    verifyNever(() => historyRepo.fetch(any()));
    expect(find.text('Edits older than 90 days are removed.'), findsOneWidget);
  });

  testWidgets('a read-only note offers no restore', (tester) async {
    when(() => notesRepo.watchNote(any())).thenAnswer(
      (_) => Stream.value(note.copyWith(permission: NotePermission.viewer)),
    );

    await pumpScreen(tester);
    await tester.tap(find.text(tenThirty));
    await tester.pumpAndSettle();

    expect(find.text('Today at $tenThirty'), findsOneWidget);
    expect(find.text('Restore'), findsNothing);
  });

  testWidgets('an empty history offline says the rest waits for a connection', (
    tester,
  ) async {
    when(() => store.watch(any())).thenAnswer((_) => Stream.value(const []));

    await pumpScreen(tester, isOnline: false);

    expect(find.text('No earlier versions yet'), findsOneWidget);
    expect(find.text(offlineMessage), findsOneWidget);
  });

  testWidgets('an unedited note is empty, with nothing to try again', (
    tester,
  ) async {
    when(() => store.watch(any())).thenAnswer((_) => Stream.value(const []));
    when(
      () => store.watchPosition(any()),
    ).thenAnswer((_) => Stream.value(const NoteHistoryPosition(isRead: true)));

    await pumpScreen(tester);

    expect(find.text('No earlier versions yet'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
  });

  testWidgets('history gone stale under the screen is read again', (
    tester,
  ) async {
    final positions = StreamController<NoteHistoryPosition>();
    addTearDown(positions.close);
    when(() => store.watchPosition(any())).thenAnswer((_) => positions.stream);

    await pumpScreen(tester);
    positions.add(const NoteHistoryPosition(cursor: 'older', isRead: true));
    await tester.pump();
    verify(() => historyRepo.fetch('n1')).called(1);

    positions.add(const NoteHistoryPosition());
    await tester.pump();
    verify(() => historyRepo.fetch('n1')).called(1);
  });

  testWidgets('a stale mark landing mid-read still triggers a fresh read', (
    tester,
  ) async {
    final positions = StreamController<NoteHistoryPosition>();
    addTearDown(positions.close);
    when(() => store.watchPosition(any())).thenAnswer((_) => positions.stream);
    final firstFetch = Completer<void>();
    when(() => historyRepo.fetch(any())).thenAnswer((_) => firstFetch.future);

    await pumpScreen(tester);
    positions.add(const NoteHistoryPosition(cursor: 'older', isRead: true));
    await tester.pump();
    verify(() => historyRepo.fetch('n1')).called(1);

    positions.add(const NoteHistoryPosition());
    await tester.pump();
    verifyNever(() => historyRepo.fetch(any()));

    when(() => historyRepo.fetch(any())).thenAnswer((_) async {});
    firstFetch.complete();
    await tester.pump();
    verify(() => historyRepo.fetch('n1')).called(1);
  });
}
