import 'package:anchor/features/notes/domain/note.dart';
import 'package:anchor/features/notes/presentation/note_folder.dart';
import 'package:anchor/features/notes/presentation/notes_controller.dart';
import 'package:anchor/features/notes/presentation/notes_list_controller.dart';
import 'package:anchor/features/notes/presentation/notes_view_options.dart';
import 'package:anchor/features/reminders/data/notification_gateway.dart';
import 'package:anchor/features/tags/presentation/tags_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'reminder_permissions_test.dart' show FakeGateway;

class _DefaultOptions extends NotesViewOptionsNotifier {
  @override
  Future<NotesViewOptions> build() async => const NotesViewOptions();
}

class _Tag extends SelectedTagFilter {
  _Tag(this.tagId);

  final String? tagId;

  @override
  String? build() => tagId;
}

class _OpenTags extends OpenArchivedTags {
  _OpenTags(this.tagIds);

  final Set<String> tagIds;

  @override
  Set<String> build() => tagIds;
}

String delta(String text) => '{"ops":[{"insert":"$text\\n"}]}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final notes = [
    Note(
      id: 'n1',
      title: 'Groceries',
      content: delta('milk and eggs'),
      updatedAt: DateTime.utc(2026, 8, 3),
    ),
    Note(
      id: 'n2',
      title: 'Trip',
      content: delta('Lisbon in May'),
      isPinned: true,
      updatedAt: DateTime.utc(2026, 8, 1),
    ),
    Note(
      id: 'n3',
      title: 'Ideas',
      content: delta('a garden'),
      updatedAt: DateTime.utc(2026, 8, 2),
    ),
  ];

  ProviderContainer containerWith({
    List<Note>? active,
    List<Note> archived = const [],
    FakeGateway? gateway,
    String? tagId,
    Set<String> openTags = const {},
  }) {
    final container = ProviderContainer(
      overrides: [
        selectedTagFilterProvider.overrideWith(() => _Tag(tagId)),
        openArchivedTagsProvider.overrideWith(() => _OpenTags(openTags)),
        notesProvider.overrideWith((ref) => Stream.value(active ?? notes)),
        allActiveNotesProvider.overrideWith(
          (ref) => Stream.value(active ?? notes),
        ),
        archivedNotesProvider.overrideWith((ref) => Stream.value(archived)),
        trashedNotesProvider.overrideWith((ref) => Stream.value(const [])),
        notesViewOptionsProvider.overrideWith(_DefaultOptions.new),
        notificationGatewayProvider.overrideWithValue(
          gateway ?? FakeGateway(notifications: true, exact: true),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<VisibleNotes> visibleIn(ProviderContainer container) async {
    final listener = container.listen(visibleNotesProvider, (_, _) {});
    addTearDown(listener.close);
    for (var turn = 0; turn < 20; turn++) {
      await Future<void>.delayed(Duration.zero);
      if (container.read(visibleNotesProvider).isLoaded &&
          container.read(notesViewOptionsProvider).hasValue) {
        break;
      }
    }
    return container.read(visibleNotesProvider);
  }

  test('Notes puts pinned notes first, under their own heading', () async {
    final shown = await visibleIn(containerWith());

    expect(shown.isLoaded, isTrue);
    expect(shown.groups.map((g) => g.kind), [
      NoteGroupKind.pinned,
      NoteGroupKind.others,
    ]);
    expect(shown.groups.first.notes.map((n) => n.id), ['n2']);
    expect(shown.groups.last.notes.map((n) => n.id), ['n1', 'n3']);
  });

  test('with nothing pinned, Notes has one group with no heading', () async {
    final unpinned = [for (final n in notes) n.copyWith(isPinned: false)];
    final shown = await visibleIn(containerWith(active: unpinned));

    expect(shown.groups, hasLength(1));
    expect(shown.groups.single.kind, NoteGroupKind.all);
  });

  test('a search finds words in the title or the text, any case', () async {
    final container = containerWith();
    container.read(searchQueryProvider.notifier).set('LISBON');
    var shown = await visibleIn(container);
    expect(shown.notes.map((n) => n.id), ['n2']);
    expect(shown.groups.single.kind, NoteGroupKind.all);

    container.read(searchQueryProvider.notifier).set('ideas');
    shown = container.read(visibleNotesProvider);
    expect(shown.notes.map((n) => n.id), ['n3']);
  });

  test('Archive shows its notes in one group', () async {
    final container = containerWith(archived: [notes[0]]);
    container.read(noteFolderProvider.notifier).go(NoteFolder.archive);
    final shown = await visibleIn(container);

    expect(shown.groups.single.kind, NoteGroupKind.all);
    expect(shown.notes.map((n) => n.id), ['n1']);
  });

  group('archived notes', () {
    final archived = [
      Note(
        id: 'a1',
        title: 'Lisbon 2025',
        content: delta('old trip'),
        isArchived: true,
        tagIds: const ['travel'],
        updatedAt: DateTime.utc(2026, 7, 1),
      ),
      Note(
        id: 'a2',
        title: 'Flights',
        content: delta('receipt'),
        isArchived: true,
        updatedAt: DateTime.utc(2026, 7, 2),
      ),
    ];
    final travel = [
      for (final note in notes)
        if (note.id != 'n3') note.copyWith(tagIds: const ['travel']),
    ];

    test('a search lists matching archived notes below the others', () async {
      final container = containerWith(archived: archived);
      container.read(searchQueryProvider.notifier).set('lisbon');
      final shown = await visibleIn(container);

      expect(shown.groups.map((g) => g.kind), [
        NoteGroupKind.all,
        NoteGroupKind.archived,
      ]);
      expect(shown.groups.last.notes.map((n) => n.id), ['a1']);
      expect(shown.groups.last.isFolded, isFalse);
      expect(shown.groups.last.canFold, isFalse);
      expect(shown.notes.map((n) => n.id), ['n2', 'a1']);
    });

    test(
      'a search that only matches archived notes lists them alone',
      () async {
        final container = containerWith(archived: archived);
        container.read(searchQueryProvider.notifier).set('receipt');
        final shown = await visibleIn(container);

        expect(shown.groups.single.kind, NoteGroupKind.archived);
        expect(shown.notes.map((n) => n.id), ['a2']);
      },
    );

    test('Notes without a search or a tag leaves archived notes out', () async {
      final shown = await visibleIn(containerWith(archived: archived));

      expect(shown.notes.map((n) => n.id), isNot(contains('a1')));
      expect(shown.listsArchived, isFalse);
    });

    test(
      'a tag\'s page folds its archived notes under their heading',
      () async {
        final shown = await visibleIn(
          containerWith(active: travel, archived: archived, tagId: 'travel'),
        );

        expect(shown.groups.map((g) => g.kind), [
          NoteGroupKind.pinned,
          NoteGroupKind.others,
          NoteGroupKind.archived,
        ]);
        final section = shown.groups.last;
        expect(section.notes.map((n) => n.id), ['a1']);
        expect(section.isFolded, isTrue);
        expect(section.canFold, isTrue);
        expect(shown.notes.map((n) => n.id), isNot(contains('a1')));
        expect(shown.showsArchived(hasOtherNotes: true), isFalse);
        expect(shown.showsArchived(hasOtherNotes: false), isTrue);
      },
    );

    test('a tag\'s page opened before shows its archived notes', () async {
      final shown = await visibleIn(
        containerWith(
          active: travel,
          archived: archived,
          tagId: 'travel',
          openTags: {'travel'},
        ),
      );

      expect(shown.groups.last.isFolded, isFalse);
      expect(shown.notes.map((n) => n.id), contains('a1'));
    });

    test('a tag with only archived notes shows them open', () async {
      final shown = await visibleIn(
        containerWith(active: const [], archived: archived, tagId: 'travel'),
      );

      expect(shown.groups.single.kind, NoteGroupKind.archived);
      expect(shown.groups.single.isFolded, isFalse);
      expect(shown.groups.single.canFold, isFalse);
      expect(shown.notes.map((n) => n.id), ['a1']);
    });

    test('tag counts include archived notes', () async {
      final container = containerWith(active: travel, archived: archived);
      final listener = container.listen(tagNoteCountsProvider, (_, _) {});
      addTearDown(listener.close);
      for (var turn = 0; turn < 10; turn++) {
        await Future<void>.delayed(Duration.zero);
      }

      expect(container.read(tagNoteCountsProvider)['travel'], 3);
    });
  });

  test('a note\'s search text is read again only when it changes', () {
    final searchText = NoteSearchText();
    final note = notes[0];

    final first = searchText.of(note);
    expect(first, contains('milk and eggs'));
    expect(
      identical(searchText.of(note.copyWith(title: 'Shop')), first),
      isTrue,
    );
    expect(
      searchText.of(note.copyWith(content: delta('Bread'))),
      contains('bread'),
    );
  });

  group('asking for reminder permissions', () {
    final withReminder = [
      notes[0].copyWith(
        reminder: const NoteReminder(remindAt: '2026-09-01T09:00'),
      ),
    ];

    Future<bool> shouldAsk(ProviderContainer container) async {
      final listener = container.listen(
        shouldAskForReminderPermissionsProvider,
        (_, _) {},
      );
      addTearDown(listener.close);
      for (var turn = 0; turn < 20; turn++) {
        await Future<void>.delayed(Duration.zero);
      }
      return container.read(shouldAskForReminderPermissionsProvider);
    }

    test('asks when a reminder would not ring on time', () async {
      final container = containerWith(
        active: withReminder,
        gateway: FakeGateway(),
      );
      expect(await shouldAsk(container), isTrue);
    });

    test('stays quiet when reminders ring on time', () async {
      final container = containerWith(active: withReminder);
      expect(await shouldAsk(container), isFalse);
    });

    test('stays quiet away from Notes', () async {
      final container = containerWith(
        active: withReminder,
        gateway: FakeGateway(),
      );
      container.read(noteFolderProvider.notifier).go(NoteFolder.trash);
      expect(await shouldAsk(container), isFalse);
    });
  });
}
