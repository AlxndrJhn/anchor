import 'package:anchor/core/network/connectivity_provider.dart';
import 'package:anchor/core/network/server_config_provider.dart';
import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/features/auth/domain/user.dart';
import 'package:anchor/features/auth/presentation/auth_controller.dart';
import 'package:anchor/features/notes/domain/note.dart';
import 'package:anchor/features/notes/domain/note_filters.dart';
import 'package:anchor/features/notes/presentation/notes_controller.dart';
import 'package:anchor/features/notes/presentation/notes_list_screen.dart';
import 'package:anchor/features/notes/presentation/notes_view_options.dart';
import 'package:anchor/features/reminders/data/reminder_permissions.dart';
import 'package:anchor/features/sync/data/sync_compatibility.dart';
import 'package:anchor/features/sync/data/sync_manager.dart';
import 'package:anchor/features/tags/domain/tag.dart';
import 'package:anchor/features/tags/presentation/tags_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String delta(String text) => '{"ops":[{"insert":"$text\\n"}]}';
  final notes = [
    Note(
      id: 'n1',
      title: 'Shopping',
      content:
          '{"ops":[{"insert":"Milk"},{"insert":"\\n","attributes":{"list":"unchecked"}}]}',
      updatedAt: DateTime.utc(2026, 8, 3),
    ),
    Note(
      id: 'n2',
      title: 'Red idea',
      content: delta('paint the door'),
      background: 'color_red',
      updatedAt: DateTime.utc(2026, 8, 2),
    ),
    Note(
      id: 'n3',
      title: 'Plain',
      content: delta('nothing much'),
      updatedAt: DateTime.utc(2026, 8, 1),
    ),
  ];

  late ProviderContainer container;

  Future<void> pumpList(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serverUrlProvider.overrideWithValue('https://example.test'),
          authControllerProvider.overrideWith(_SignedIn.new),
          notesProvider.overrideWith((ref) => Stream.value(notes)),
          archivedNotesProvider.overrideWith((ref) => Stream.value([])),
          trashedNotesProvider.overrideWith((ref) => Stream.value([])),
          allActiveNotesProvider.overrideWith((ref) => Stream.value(notes)),
          tagsControllerProvider.overrideWith(_Tags.new),
          notesViewOptionsProvider.overrideWith(_ViewOptions.new),
          reminderPermissionsControllerProvider.overrideWith(_Permissions.new),
          syncManagerProvider.overrideWith(_Sync.new),
          syncCompatibilityProvider.overrideWith(
            (ref) async => SyncCompatibility.ok,
          ),
          isOnlineProvider.overrideWith((ref) => true),
          firstDownloadProvider.overrideWithValue(FirstDownload.done),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            container = ProviderScope.containerOf(context);
            return MaterialApp(
              theme: AppTheme.light(),
              home: const NotesListScreen(),
            );
          },
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> startSearch(WidgetTester tester) async {
    await tester.tap(find.bySemanticsLabel('Search notes'));
    await tester.pumpAndSettle();
  }

  testWidgets('the filter button sits in the search field only', (
    tester,
  ) async {
    await pumpList(tester);
    expect(find.bySemanticsLabel('Filter notes'), findsNothing);

    await startSearch(tester);
    expect(find.bySemanticsLabel('Filter notes'), findsOneWidget);
  });

  testWidgets('a filter narrows the list, and ending the search clears it', (
    tester,
  ) async {
    await pumpList(tester);
    await startSearch(tester);

    await tester.tap(find.bySemanticsLabel('Filter notes'));
    await tester.pumpAndSettle();
    expect(find.text('Show only notes that match'), findsOneWidget);
    await tester.tap(find.text('Checklists'));
    await tester.pumpAndSettle();
    expect(find.text('1 filter on'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Red'));
    await tester.pumpAndSettle();
    expect(find.text('2 filters on'), findsOneWidget);
    expect(
      container.read(noteFiltersControllerProvider),
      const NoteFilters(background: 'color_red', checklist: true),
    );
    // Neither note has both.
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('No notes match'), findsOneWidget);
    expect(find.bySemanticsLabel('Filter notes, 2 filters on'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Filter notes, 2 filters on'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Red'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Shopping'), findsOneWidget);
    expect(find.text('Red idea'), findsNothing);
    expect(find.text('Plain'), findsNothing);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(container.read(noteFiltersControllerProvider), NoteFilters.none);
    expect(find.text('Red idea'), findsOneWidget);
    expect(find.text('Plain'), findsOneWidget);
  });

  testWidgets('Clear filters turns every filter off', (tester) async {
    await pumpList(tester);
    await startSearch(tester);
    container
        .read(noteFiltersControllerProvider.notifier)
        .set(const NoteFilters(picture: true, reminder: true));
    await tester.pump();

    await tester.tap(find.bySemanticsLabel('Filter notes, 2 filters on'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();

    expect(container.read(noteFiltersControllerProvider), NoteFilters.none);
    expect(find.text('Clear filters'), findsNothing);
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
  @override
  Future<NotesViewOptions> build() async => const NotesViewOptions();
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
  int requests = 0;

  @override
  bool build() => false;

  @override
  Future<bool> requestSync() async {
    requests++;
    return false;
  }
}
