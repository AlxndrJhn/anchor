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
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockNotesRepository extends Mock implements NotesRepository {}

void main() {
  String delta(String text) => '{"ops":[{"insert":"$text\\n"}]}';
  final notes = [
    Note(
      id: 'n1',
      title: 'Red idea',
      content: delta('paint the door'),
      background: 'color_red',
      updatedAt: DateTime.utc(2026, 8, 3),
    ),
    Note(
      id: 'n2',
      title: 'Plain',
      content: delta('nothing much'),
      updatedAt: DateTime.utc(2026, 8, 2),
    ),
    Note(
      id: 'n3',
      title: 'Theirs',
      content: delta('look only'),
      permission: NotePermission.viewer,
      updatedAt: DateTime.utc(2026, 8, 1),
    ),
  ];

  late _MockNotesRepository repo;

  setUp(() {
    repo = _MockNotesRepository();
    when(() => repo.setBackground(any(), any())).thenAnswer(
      (call) async => [
        for (final id in call.positionalArguments.first as List<String>)
          if (id != 'n3') id,
      ],
    );
  });

  Future<void> pumpList(WidgetTester tester) async {
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
          notesViewOptionsProvider.overrideWith(_ViewOptions.new),
          reminderPermissionsControllerProvider.overrideWith(_Permissions.new),
          syncManagerProvider.overrideWith(_Sync.new),
          syncCompatibilityProvider.overrideWith(
            (ref) async => SyncCompatibility.ok,
          ),
          isOnlineProvider.overrideWith((ref) => true),
          firstDownloadProvider.overrideWithValue(FirstDownload.done),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const NotesListScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> select(WidgetTester tester, List<String> titles) async {
    await tester.longPress(find.text(titles.first));
    await tester.pumpAndSettle();
    for (final title in titles.skip(1)) {
      await tester.tap(find.text(title));
      await tester.pumpAndSettle();
    }
  }

  Future<void> pickColor(WidgetTester tester, String name) async {
    await tester.tap(find.bySemanticsLabel('Color'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel(name));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    // Not settled: that would wait out the toast.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('Color gives the selected notes one color, with Undo', (
    tester,
  ) async {
    await pumpList(tester);
    await select(tester, ['Red idea', 'Plain']);
    expect(find.text('2 selected'), findsOneWidget);

    await pickColor(tester, 'Blue');

    verify(() => repo.setBackground(['n1', 'n2'], 'color_blue')).called(1);
    expect(
      find.textContaining('Color changed on 2', findRichText: true),
      findsOneWidget,
    );

    await tester.tap(find.text('Undo'));
    await tester.pump();
    verify(() => repo.setBackground(['n1'], 'color_red')).called(1);
    verify(() => repo.setBackground(['n2'], null)).called(1);
    await tester.pumpAndSettle();
    // Selection ended.
    expect(find.text('2 selected'), findsNothing);
    expect(find.text('Pattern'), findsNothing);
  });

  testWidgets('a note shared with you to view keeps its color', (tester) async {
    await pumpList(tester);
    await select(tester, ['Plain', 'Theirs']);

    await pickColor(tester, 'Green');

    verify(() => repo.setBackground(['n2', 'n3'], 'color_green')).called(1);
    expect(
      find.textContaining('1 note shared with you to view', findRichText: true),
      findsOneWidget,
    );
    await tester.pumpAndSettle();
  });

  testWidgets('closing the sheet without a pick changes nothing', (
    tester,
  ) async {
    await pumpList(tester);
    await select(tester, ['Plain']);

    await tester.tap(find.bySemanticsLabel('Color'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    verifyNever(() => repo.setBackground(any(), any()));
    expect(find.bySemanticsLabel('Color'), findsOneWidget);
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
