import 'package:anchor/core/network/connectivity_provider.dart';
import 'package:anchor/core/network/server_config_provider.dart';
import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/features/auth/domain/user.dart';
import 'package:anchor/features/auth/presentation/auth_controller.dart';
import 'package:anchor/features/notes/domain/note.dart';
import 'package:anchor/features/notes/presentation/notes_controller.dart';
import 'package:anchor/features/notes/presentation/notes_list_screen.dart';
import 'package:anchor/features/notes/presentation/notes_view_options.dart';
import 'package:anchor/features/notes/presentation/widgets/note_cards_loading.dart';
import 'package:anchor/features/reminders/data/reminder_permissions.dart';
import 'package:anchor/features/sync/data/sync_compatibility.dart';
import 'package:anchor/features/sync/data/sync_manager.dart';
import 'package:anchor/features/tags/domain/tag.dart';
import 'package:anchor/features/tags/presentation/tags_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _Sync sync;

  Future<void> pumpList(
    WidgetTester tester, {
    required FirstDownload firstDownload,
  }) async {
    sync = _Sync();
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serverUrlProvider.overrideWithValue('https://example.test'),
          authControllerProvider.overrideWith(_SignedIn.new),
          notesProvider.overrideWith((ref) => Stream.value(const <Note>[])),
          archivedNotesProvider.overrideWith((ref) => Stream.value([])),
          trashedNotesProvider.overrideWith((ref) => Stream.value([])),
          allActiveNotesProvider.overrideWith((ref) => Stream.value([])),
          tagsControllerProvider.overrideWith(_Tags.new),
          notesViewOptionsProvider.overrideWith(_ViewOptions.new),
          reminderPermissionsControllerProvider.overrideWith(_Permissions.new),
          syncManagerProvider.overrideWith(() => sync),
          syncCompatibilityProvider.overrideWith(
            (ref) async => SyncCompatibility.ok,
          ),
          isOnlineProvider.overrideWith((ref) => true),
          firstDownloadProvider.overrideWithValue(firstDownload),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const NotesListScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('an empty list waits for the first download', (tester) async {
    await pumpList(tester, firstDownload: FirstDownload.running);
    expect(find.byType(NoteCardsLoading), findsOneWidget);
    expect(find.text('No notes yet'), findsNothing);
  });

  testWidgets('an empty list after it says so', (tester) async {
    await pumpList(tester, firstDownload: FirstDownload.done);
    expect(find.byType(NoteCardsLoading), findsNothing);
    expect(find.text('No notes yet'), findsOneWidget);
  });

  testWidgets('a first download that failed says so and can be tried again', (
    tester,
  ) async {
    await pumpList(tester, firstDownload: FirstDownload.failed);
    expect(find.text('No notes yet'), findsNothing);
    expect(find.text('Couldn’t load your notes'), findsOneWidget);
    expect(find.text('Check your connection, then try again.'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    expect(sync.requests, 1);
  });

  testWidgets('a paused first download leaves the fix to the warning above', (
    tester,
  ) async {
    await pumpList(tester, firstDownload: FirstDownload.paused);
    expect(find.text('Couldn’t load your notes'), findsOneWidget);
    expect(
      find.text('Your notes will appear here once they sync.'),
      findsOneWidget,
    );
    expect(find.text('Try again'), findsNothing);
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
