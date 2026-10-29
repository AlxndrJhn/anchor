import 'package:anchor/core/network/connectivity_provider.dart';
import 'package:anchor/core/network/server_config_provider.dart';
import 'package:anchor/core/storage/preferences_repository.dart';
import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/core/theme/display_density.dart';
import 'package:anchor/core/theme/tokens/anchor_tokens.dart';
import 'package:anchor/core/widgets/pressable.dart';
import 'package:anchor/features/auth/domain/user.dart';
import 'package:anchor/features/auth/presentation/auth_controller.dart';
import 'package:anchor/features/notes/data/repository/notes_repository.dart';
import 'package:anchor/features/notes/domain/note.dart';
import 'package:anchor/features/notes/presentation/notes_controller.dart';
import 'package:anchor/features/notes/presentation/notes_list_controller.dart';
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

class _MockNotes extends Mock implements NotesRepository {}

class _MockPreferences extends Mock implements PreferencesRepository {}

void main() {
  late _MockNotes repo;
  late _MockPreferences preferences;

  final trip = Note(
    id: 'n1',
    title: 'Lisbon trip',
    content: '{"ops":[{"insert":"Tram 28\\n"}]}',
    tagIds: const ['travel'],
    updatedAt: DateTime.utc(2026, 10, 2),
  );
  final oldTrip = Note(
    id: 'a1',
    title: 'Lisbon 2025',
    content: '{"ops":[{"insert":"Tram 15\\n"}]}',
    isArchived: true,
    tagIds: const ['travel'],
    updatedAt: DateTime.utc(2026, 7, 1),
  );

  setUp(() {
    repo = _MockNotes();
    preferences = _MockPreferences();
    when(() => repo.archive(any())).thenAnswer((_) async {});
    when(() => repo.unarchive(any())).thenAnswer((_) async {});
    when(() => preferences.setOpenArchivedTags(any())).thenAnswer((_) async {});
  });

  Future<ProviderContainer> pumpList(
    WidgetTester tester, {
    String? tagId,
    String query = '',
    DisplayDensity density = DisplayDensity.standard,
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
          preferencesRepositoryProvider.overrideWithValue(preferences),
          notesProvider.overrideWith((ref) => Stream.value([trip])),
          archivedNotesProvider.overrideWith((ref) => Stream.value([oldTrip])),
          trashedNotesProvider.overrideWith((ref) => Stream.value([])),
          allActiveNotesProvider.overrideWith((ref) => Stream.value([trip])),
          tagsControllerProvider.overrideWith(_Tags.new),
          selectedTagFilterProvider.overrideWith(() => _Tag(tagId)),
          searchQueryProvider.overrideWith(() => _Query(query)),
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
          theme: AppTheme.light(density),
          home: const NotesListScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    return ProviderScope.containerOf(
      tester.element(find.byType(NotesListScreen)),
    );
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('a tag\'s page folds its archived notes, and a tap on the '
      'heading opens them', (tester) async {
    final semantics = tester.ensureSemantics();
    final container = await pumpList(tester, tagId: 'travel');

    expect(find.text('ARCHIVED'), findsOneWidget);
    expect(find.text('Lisbon trip'), findsOneWidget);
    expect(find.text('Lisbon 2025'), findsNothing);
    final heading = find.ancestor(
      of: find.text('ARCHIVED'),
      matching: find.byType(Pressable),
    );
    expect(
      tester.getSize(heading).height,
      greaterThanOrEqualTo(AnchorTokens.sizeTargetTouch),
    );
    expect(
      tester.getSemantics(find.text('ARCHIVED')),
      isSemantics(
        label: 'Archived, 1',
        isHeader: true,
        isButton: true,
        hasExpandedState: true,
        isExpanded: false,
        hasTapAction: true,
      ),
    );

    await tester.tap(find.text('ARCHIVED'));
    await settle(tester);

    expect(find.text('Lisbon 2025'), findsOneWidget);
    expect(
      tester.getSemantics(find.text('ARCHIVED')),
      isSemantics(hasExpandedState: true, isExpanded: true),
    );
    semantics.dispose();
    expect(container.read(openArchivedTagsProvider), {'travel'});
    verify(() => preferences.setOpenArchivedTags(['travel'])).called(1);
  });

  testWidgets('the heading keeps a full tap area in Compact', (tester) async {
    await pumpList(tester, tagId: 'travel', density: DisplayDensity.compact);

    final heading = find.ancestor(
      of: find.text('ARCHIVED'),
      matching: find.byType(Pressable),
    );
    expect(
      tester.getSize(heading).height,
      greaterThanOrEqualTo(AnchorTokens.sizeTargetTouch),
    );
  });

  testWidgets('archived notes fade in each time their section opens', (
    tester,
  ) async {
    await pumpList(tester, tagId: 'travel');
    double opacityOf(String title) {
      final fades = tester.widgetList<Opacity>(
        find.ancestor(of: find.text(title), matching: find.byType(Opacity)),
      );
      return fades.fold(1, (opacity, fade) => opacity * fade.opacity);
    }

    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text('ARCHIVED'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(opacityOf('Lisbon 2025'), lessThan(1), reason: 'open $i');
      await settle(tester);
      expect(opacityOf('Lisbon 2025'), 1);

      await tester.tap(find.text('ARCHIVED'));
      await settle(tester);
      expect(find.text('Lisbon 2025'), findsNothing);
    }
  });

  testWidgets('a search lists archived matches under their own heading', (
    tester,
  ) async {
    await pumpList(tester, query: 'lisbon');

    expect(find.text('Lisbon trip'), findsOneWidget);
    expect(find.text('ARCHIVED'), findsOneWidget);
    expect(find.text('Lisbon 2025'), findsOneWidget);
  });

  testWidgets('with only archived notes picked, Archive turns into '
      'Unarchive', (tester) async {
    await pumpList(tester, query: 'lisbon');

    await tester.longPress(find.text('Lisbon 2025'));
    await settle(tester);
    expect(find.text('Unarchive'), findsOneWidget);

    await tester.tap(find.text('Lisbon trip'));
    await settle(tester);
    expect(find.text('Unarchive'), findsNothing);
    expect(find.text('Archive'), findsOneWidget);

    await tester.tap(find.text('Lisbon trip'));
    await settle(tester);
    await tester.tap(find.text('Unarchive'));
    await settle(tester);

    verify(() => repo.unarchive(['a1'])).called(1);
    verifyNever(() => repo.archive(any()));
    await tester.pump(const Duration(seconds: 7));
  });

  testWidgets('Archive with an archived note picked archives and undoes '
      'only the others', (tester) async {
    await pumpList(tester, query: 'lisbon');

    await tester.longPress(find.text('Lisbon 2025'));
    await settle(tester);
    await tester.tap(find.text('Lisbon trip'));
    await settle(tester);
    await tester.tap(find.text('Archive'));
    await settle(tester);

    verify(() => repo.archive(['n1'])).called(1);
    expect(find.text('Note archived'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await settle(tester);
    verify(() => repo.unarchive(['n1'])).called(1);
    await tester.pump(const Duration(seconds: 7));
  });
}

class _SignedIn extends AuthController {
  @override
  Future<User?> build() async =>
      const User(id: 'u1', email: 'oliver@example.com', name: 'Oliver Grant');
}

class _Tags extends TagsController {
  @override
  Stream<List<Tag>> build() =>
      Stream.value(const [Tag(id: 'travel', name: 'travel', color: '#2f7d6d')]);
}

class _Tag extends SelectedTagFilter {
  _Tag(this.tagId);

  final String? tagId;

  @override
  String? build() => tagId;
}

class _Query extends SearchQuery {
  _Query(this.query);

  final String query;

  @override
  String build() => query;
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
  @override
  bool build() => false;
}
