import 'package:anchor/core/widgets/destruction/destruction.dart';
import 'dart:async';

import 'package:anchor/core/network/connectivity_provider.dart';
import 'package:anchor/core/network/server_config_provider.dart';
import 'package:anchor/core/providers/active_user_id_provider.dart';
import 'package:anchor/core/widgets/confirm_dialog.dart';
import 'package:anchor/core/widgets/rich_text_editor.dart';
import 'package:anchor/features/notes/data/repository/note_attachments_repository.dart';
import 'package:anchor/features/notes/data/repository/notes_repository.dart';
import 'package:anchor/core/notifications/notification_gateway.dart';
import 'package:anchor/features/notes/domain/note.dart';
import 'package:anchor/features/notes/presentation/note_edit_screen.dart';
import 'package:anchor/features/notes/presentation/widgets/reminder_chip.dart';
import 'package:anchor/features/settings/presentation/controllers/editor_preferences_controller.dart';
import 'package:anchor/features/settings/data/repository/preferences_repository.dart';
import 'package:anchor/features/tags/data/repository/tags_repository.dart';
import 'package:anchor/features/tags/domain/tag.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mocktail/mocktail.dart';

import 'reminder_permissions_test.dart' show FakeGateway;

class MockNotesRepository extends Mock implements NotesRepository {}

class MockTagsRepository extends Mock implements TagsRepository {}

class MockAttachmentsRepository extends Mock
    implements NoteAttachmentsRepository {}

class MockPreferencesRepository extends Mock implements PreferencesRepository {}

class FakeActiveUserId extends ActiveUserId {
  @override
  String? build() => 'user-1';
}

/// Dirty-tracking and auto-save flow of NoteEditScreen against mocked
/// repositories. The 2s auto-save timer is driven with tester.pump.
void main() {
  late MockNotesRepository notesRepo;
  late MockTagsRepository tagsRepo;
  late MockAttachmentsRepository attachmentsRepo;
  late MockPreferencesRepository prefsRepo;

  setUpAll(() {
    registerFallbackValue(const Note(id: 'fallback', title: ''));
  });

  setUp(() {
    notesRepo = MockNotesRepository();
    tagsRepo = MockTagsRepository();
    attachmentsRepo = MockAttachmentsRepository();
    prefsRepo = MockPreferencesRepository();

    when(() => notesRepo.createNote(any())).thenAnswer((_) async {});
    when(() => notesRepo.updateNote(any())).thenAnswer((_) async {});
    when(
      () => notesRepo.watchNote(any()),
    ).thenAnswer((_) => const Stream<Note?>.empty());
    when(
      () => tagsRepo.watchTags(),
    ).thenAnswer((_) => Stream.value(const <Tag>[]));
    when(
      () => attachmentsRepo.watchAttachments(any()),
    ).thenAnswer((_) => Stream.value(const []));
    when(() => prefsRepo.getSortChecklistItems()).thenAnswer((_) async => true);
    when(() => prefsRepo.getBurnDeleted()).thenAnswer((_) async => true);
    when(() => prefsRepo.getExactAlarmsOffered()).thenAnswer((_) async => true);
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    Note? note,
    bool pasteClipboard = false,
    // Opened from a list holding the note's card, as from the notes list.
    bool fromList = false,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notesRepositoryProvider.overrideWithValue(notesRepo),
          tagsRepositoryProvider.overrideWithValue(tagsRepo),
          noteAttachmentsRepositoryProvider.overrideWithValue(attachmentsRepo),
          preferencesRepositoryProvider.overrideWithValue(prefsRepo),
          serverUrlProvider.overrideWith((ref) => null),
          connectivityStreamProvider.overrideWith(
            (ref) => const Stream<List<ConnectivityResult>>.empty(),
          ),
          activeUserIdProvider.overrideWith(FakeActiveUserId.new),
          notificationGatewayProvider.overrideWithValue(FakeGateway()),
        ],
        child: MaterialApp.router(
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            FlutterQuillLocalizations.delegate,
          ],
          // ConfirmDialog pops through GoRouter.
          routerConfig: GoRouter(
            initialLocation: fromList ? '/note' : '/',
            routes: [
              GoRoute(
                path: '/',
                builder: (_, _) => fromList
                    ? Scaffold(
                        body: Destructible(
                          id: note!.id,
                          child: const SizedBox(
                            width: 160,
                            height: 120,
                            child: Text('The card'),
                          ),
                        ),
                      )
                    : NoteEditScreen(
                        note: note,
                        noteId: note?.id,
                        pasteClipboard: pasteClipboard,
                      ),
                routes: [
                  GoRoute(
                    path: 'note',
                    builder: (_, _) =>
                        NoteEditScreen(note: note, noteId: note?.id),
                  ),
                  // Where Undo of a trash opens the note again.
                  GoRoute(
                    path: 'note/:id',
                    builder: (_, state) => NoteEditScreen(
                      noteId: state.pathParameters['id'],
                      caret: state.extra as NoteCaret?,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
  }

  final titleField = find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.hintText == 'Title',
  );

  QuillController editorController(WidgetTester tester) =>
      tester.state<RichTextEditorState>(find.byType(RichTextEditor)).controller;

  testWidgets('a note opened by double-tapping New Note has the clipboard', (
    tester,
  ) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => call.method == 'Clipboard.getData'
          ? {'text': '  Copied from the browser  '}
          : null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await pumpScreen(tester, pasteClipboard: true);
    await tester.pump();

    final controller = editorController(tester);
    expect(controller.document.toPlainText(), 'Copied from the browser\n');
    expect(
      controller.selection,
      const TextSelection.collapsed(offset: 'Copied from the browser'.length),
    );
  });

  testWidgets('typing in a new note autosaves it after the idle window', (
    tester,
  ) async {
    await pumpScreen(tester);

    editorController(tester).replaceText(0, 0, 'hello', null);
    await tester.pump();
    verifyNever(() => notesRepo.createNote(any()));

    await tester.pump(const Duration(seconds: 3));

    final captured = verify(() => notesRepo.createNote(captureAny())).captured;
    expect(captured, hasLength(1));
    final note = captured.single as Note;
    expect(note.content, contains('hello'));
    expect(note.title, isEmpty);
  });

  testWidgets('a new note opens with the caret in its text', (tester) async {
    await pumpScreen(tester);
    await tester.pump();

    final editable = find.descendant(
      of: find.byType(RichTextEditor),
      matching: find.byType(QuillEditor),
    );
    expect(tester.widget<QuillEditor>(editable).focusNode.hasFocus, isTrue);
    expect(editorController(tester).selection.baseOffset, 0);
  });

  testWidgets('an untouched new note is never saved', (tester) async {
    await pumpScreen(tester);

    await tester.pump(const Duration(seconds: 3));

    verifyNever(() => notesRepo.createNote(any()));
    verifyNever(() => notesRepo.updateNote(any()));
  });

  testWidgets('typing a title autosaves a new note with that title', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.enterText(titleField, 'My title');
    await tester.pump(const Duration(seconds: 3));

    final captured = verify(() => notesRepo.createNote(captureAny())).captured;
    expect(captured, hasLength(1));
    expect((captured.single as Note).title, 'My title');
  });

  testWidgets('the bar has pin, archive and delete; share is in the menu', (
    tester,
  ) async {
    const note = Note(
      id: 'n1',
      title: 'Mine',
      content: '{"ops":[{"insert":"hi\\n"}]}',
    );
    await pumpScreen(tester, note: note);

    expect(find.byTooltip('Pin Note'), findsOneWidget);
    expect(find.byTooltip('Archive note'), findsOneWidget);
    expect(find.byTooltip('Delete note'), findsOneWidget);
    expect(find.byTooltip('Share Note'), findsNothing);

    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    expect(find.text('Share'), findsOneWidget);
  });

  testWidgets('a frozen note reads only, has no delete, and offers Unfreeze', (
    tester,
  ) async {
    const note = Note(
      id: 'n1',
      title: 'Deed',
      content: '{"ops":[{"insert":"hi\\n"}]}',
      isFrozen: true,
    );
    await pumpScreen(tester, note: note);

    expect(find.byTooltip('Pin Note'), findsOneWidget);
    expect(find.byTooltip('Delete note'), findsNothing);
    expect(find.textContaining('Frozen.'), findsOneWidget);
    expect(find.text('Unfreeze'), findsOneWidget);
    expect(editorController(tester).readOnly, isTrue);

    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    expect(find.text('Unfreeze'), findsNWidgets(2));
  });

  testWidgets('deleting your note asks nothing and offers Undo', (
    tester,
  ) async {
    when(() => notesRepo.deleteNote(any())).thenAnswer((_) async {});
    when(() => notesRepo.restoreNote(any())).thenAnswer((_) async {});
    const note = Note(
      id: 'n1',
      title: 'Mine',
      content: '{"ops":[{"insert":"hi\\n"}]}',
    );
    await pumpScreen(tester, note: note);

    await tester.tap(find.byTooltip('Delete note'));
    await tester.pumpAndSettle();

    expect(find.byType(ConfirmDialog), findsNothing);
    verify(() => notesRepo.deleteNote('n1')).called(1);
    expect(find.text('Note moved to trash'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    verify(() => notesRepo.restoreNote('n1')).called(1);
  });

  testWidgets('a deleted note closes at once; its card burns, then it goes', (
    tester,
  ) async {
    when(() => notesRepo.deleteNote(any())).thenAnswer((_) async {});
    const note = Note(
      id: 'n1',
      title: 'Mine',
      content: '{"ops":[{"insert":"hi\\n"}]}',
    );
    await pumpScreen(tester, note: note, fromList: true);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Delete note'));
    await tester.pump();
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    // Closed, back on the list, where the card burns in place.
    expect(find.byType(NoteEditScreen), findsNothing);
    expect(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is BurnPainter,
      ),
      findsOneWidget,
    );
    verifyNever(() => notesRepo.deleteNote(any()));

    await tester.pumpAndSettle();
    verify(() => notesRepo.deleteNote('n1')).called(1);
    expect(find.text('Note moved to trash'), findsOneWidget);
  });

  group('undoing a trash opens the note again', () {
    const note = Note(
      id: 'n1',
      title: 'My title',
      content: '{"ops":[{"insert":"hello world\\n"}]}',
    );

    Future<void> trashThenUndo(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Delete note'));
      await tester.pumpAndSettle();
      expect(find.byType(NoteEditScreen), findsNothing);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      verify(() => notesRepo.restoreNote('n1')).called(1);
      expect(find.byType(NoteEditScreen), findsOneWidget);
    }

    setUp(() {
      when(() => notesRepo.deleteNote(any())).thenAnswer((_) async {});
      when(() => notesRepo.restoreNote(any())).thenAnswer((_) async {});
      when(() => notesRepo.getNote('n1')).thenAnswer((_) async => note);
    });

    testWidgets('with the caret where it was in the text', (tester) async {
      await pumpScreen(tester, note: note, fromList: true);
      await tester.pumpAndSettle();
      tester
          .state<RichTextEditorState>(find.byType(RichTextEditor))
          .focusAt(const TextSelection(baseOffset: 3, extentOffset: 7));
      await tester.pump();

      await trashThenUndo(tester);

      final editable = find.descendant(
        of: find.byType(RichTextEditor),
        matching: find.byType(QuillEditor),
      );
      expect(tester.widget<QuillEditor>(editable).focusNode.hasFocus, isTrue);
      expect(
        editorController(tester).selection,
        const TextSelection(baseOffset: 3, extentOffset: 7),
      );
    });

    testWidgets('with the caret where it was in the title', (tester) async {
      await pumpScreen(tester, note: note, fromList: true);
      await tester.pumpAndSettle();
      await tester.tap(titleField);
      await tester.pump();
      tester.widget<TextField>(titleField).controller!.selection =
          const TextSelection.collapsed(offset: 2);
      await tester.pump();

      await trashThenUndo(tester);

      final title = tester.widget<TextField>(titleField);
      expect(title.focusNode!.hasFocus, isTrue);
      expect(title.controller!.selection.baseOffset, 2);
    });
  });

  testWidgets('Show checkboxes turns every line into an unchecked item', (
    tester,
  ) async {
    const note = Note(
      id: 'n1',
      title: 'Groceries',
      content: '{"ops":[{"insert":"Milk\\nEggs\\n"}]}',
    );
    await pumpScreen(tester, note: note);

    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    expect(find.text('Hide checkboxes'), findsNothing);
    await tester.tap(find.byIcon(LucideIcons.listChecks));
    await tester.pumpAndSettle();

    final ops = editorController(tester).document.toDelta().toJson();
    expect(
      ops.where((op) => (op['attributes'] as Map?)?['list'] == 'unchecked'),
      hasLength(2),
    );

    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    expect(find.text('Show checkboxes'), findsNothing);
    expect(find.text('Hide checkboxes'), findsOneWidget);
  });

  testWidgets('cursor movement alone never saves an existing note', (
    tester,
  ) async {
    const note = Note(
      id: 'n1',
      title: 'T',
      content: '{"ops":[{"insert":"hi\\n"}]}',
    );
    await pumpScreen(tester, note: note);

    editorController(tester).updateSelection(
      const TextSelection.collapsed(offset: 1),
      ChangeSource.local,
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));

    verifyNever(() => notesRepo.updateNote(any()));
    verifyNever(() => notesRepo.createNote(any()));
  });

  testWidgets('leaving an untouched note with a spaced title saves nothing', (
    tester,
  ) async {
    const note = Note(
      id: 'n1',
      title: 'Renovierung ',
      content: '{"ops":[{"insert":"hi\\n"}]}',
    );
    await pumpScreen(tester, note: note);

    await tester.tap(find.byIcon(LucideIcons.chevronLeft));
    await tester.pumpAndSettle();

    verifyNever(() => notesRepo.updateNote(any()));
  });

  testWidgets('a read-only note with no title shows no title', (tester) async {
    const note = Note(
      id: 'n1',
      title: '',
      content: '{"ops":[{"insert":"hi\\n"}]}',
      state: NoteState.trashed,
    );
    await pumpScreen(tester, note: note);

    expect(titleField, findsNothing);
    expect(find.text('Untitled'), findsNothing);
  });

  testWidgets('keeps a title exactly as typed', (tester) async {
    const note = Note(
      id: 'n1',
      title: 'T',
      content: '{"ops":[{"insert":"hi\\n"}]}',
    );
    await pumpScreen(tester, note: note);

    await tester.enterText(titleField, ' Shopping list ');
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));

    final saved =
        verify(() => notesRepo.updateNote(captureAny())).captured.last as Note;
    expect(saved.title, ' Shopping list ');
  });

  testWidgets('a title edit keeps the stored text exactly as it was', (
    tester,
  ) async {
    // Formatted differently from what the editor writes.
    const content = '{"ops": [{"insert": "milk"}, {"insert": ", eggs\\n"}]}';
    const note = Note(id: 'n1', title: 'Shopping', content: content);
    await pumpScreen(tester, note: note);

    await tester.enterText(titleField, 'Weekly shop');
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));

    final saved =
        verify(() => notesRepo.updateNote(captureAny())).captured.last as Note;
    expect(saved.title, 'Weekly shop');
    expect(saved.content, content);
  });

  testWidgets('saves a title of only spaces as no title', (tester) async {
    const note = Note(
      id: 'n1',
      title: 'T',
      content: '{"ops":[{"insert":"hi\\n"}]}',
    );
    await pumpScreen(tester, note: note);

    await tester.enterText(titleField, '   ');
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));

    final saved =
        verify(() => notesRepo.updateNote(captureAny())).captured.last as Note;
    expect(saved.title, isEmpty);
  });

  testWidgets('leaving an untouched imported note with a link saves nothing', (
    tester,
  ) async {
    const note = Note(
      id: 'n1',
      title: 'Birdhouse',
      content:
          '{"ops":[{"insert":"Build a birdhouse\\n"},{"insert":"\\n"},'
          '{"insert":"https://example.com","attributes":{"link":"https://example.com"}},'
          '{"insert":"\\n"}]}',
    );
    await pumpScreen(tester, note: note);

    await tester.tap(find.byIcon(LucideIcons.chevronLeft));
    await tester.pumpAndSettle();

    verifyNever(() => notesRepo.updateNote(any()));
  });

  testWidgets('leaving an untouched note with no body saves nothing', (
    tester,
  ) async {
    const note = Note(id: 'n1', title: 'Just a title');
    await pumpScreen(tester, note: note);

    await tester.tap(find.byIcon(LucideIcons.chevronLeft));
    await tester.pumpAndSettle();

    verifyNever(() => notesRepo.updateNote(any()));
  });

  testWidgets('restoring a trashed note reloads its content into the editor', (
    tester,
  ) async {
    const trashed = Note(
      id: 'n1',
      title: 'T',
      content: '{"ops":[{"insert":"old content\\n"}]}',
      state: NoteState.trashed,
    );
    const restored = Note(
      id: 'n1',
      title: 'T',
      content: '{"ops":[{"insert":"fresh content\\n"}]}',
    );
    when(() => notesRepo.restoreNote('n1')).thenAnswer((_) async {});
    when(() => notesRepo.getNote('n1')).thenAnswer((_) async => restored);

    await pumpScreen(tester, note: trashed);
    expect(find.text('old content', findRichText: true), findsOneWidget);

    await tester.tap(find.byTooltip('Restore note'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Restore'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('fresh content', findRichText: true), findsOneWidget);
    expect(find.text('old content', findRichText: true), findsNothing);
    verify(() => notesRepo.restoreNote('n1')).called(1);

    // Drain the success snackbar's display timer.
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('a note changed elsewhere replaces what is on screen', (
    tester,
  ) async {
    const note = Note(
      id: 'n1',
      title: 'Mine',
      content: '{"ops":[{"insert":"mine\\n"}]}',
    );
    final stored = StreamController<Note?>();
    when(() => notesRepo.watchNote('n1')).thenAnswer((_) => stored.stream);

    await pumpScreen(tester, note: note);
    expect(find.text('mine', findRichText: true), findsOneWidget);

    stored.add(
      const Note(
        id: 'n1',
        title: 'Theirs',
        content: '{"ops":[{"insert":"theirs\\n"}]}',
      ),
    );
    await tester.pump();

    expect(find.text('theirs', findRichText: true), findsOneWidget);
    expect(find.text('mine', findRichText: true), findsNothing);
    verifyNever(() => notesRepo.updateNote(any()));

    await stored.close();
  });

  testWidgets('an unsaved edit outlives a note changed elsewhere', (
    tester,
  ) async {
    const note = Note(
      id: 'n1',
      title: 'T',
      content: '{"ops":[{"insert":"hi\\n"}]}',
    );
    final stored = StreamController<Note?>();
    when(() => notesRepo.watchNote('n1')).thenAnswer((_) => stored.stream);

    await pumpScreen(tester, note: note);
    editorController(tester).replaceText(0, 0, 'x', null);
    await tester.pump();

    stored.add(
      const Note(
        id: 'n1',
        title: 'T',
        content: '{"ops":[{"insert":"theirs\\n"}]}',
      ),
    );
    await tester.pump();

    expect(find.text('xhi', findRichText: true), findsOneWidget);
    expect(find.text('theirs', findRichText: true), findsNothing);

    await tester.pump(const Duration(seconds: 3));
    final saved =
        verify(() => notesRepo.updateNote(captureAny())).captured.single
            as Note;
    expect(saved.content, contains('xhi'));

    await stored.close();
  });

  testWidgets('clearing an existing note saves it empty', (tester) async {
    const note = Note(
      id: 'n1',
      title: 'T',
      content: '{"ops":[{"insert":"hi\\n"}]}',
    );
    await pumpScreen(tester, note: note);

    await tester.enterText(titleField, '');
    final controller = editorController(tester);
    controller.replaceText(0, controller.document.length - 1, '', null);
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));

    final captured = verify(() => notesRepo.updateNote(captureAny())).captured;
    final saved = captured.last as Note;
    expect(saved.id, 'n1');
    expect(saved.title, isEmpty);
    expect(saved.content, isNot(contains('hi')));
  });

  testWidgets('editing an existing note autosaves an update', (tester) async {
    const note = Note(
      id: 'n1',
      title: 'T',
      content: '{"ops":[{"insert":"hi\\n"}]}',
    );
    await pumpScreen(tester, note: note);

    editorController(tester).replaceText(0, 0, 'x', null);
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));

    final captured = verify(() => notesRepo.updateNote(captureAny())).captured;
    expect(captured, hasLength(1));
    final saved = captured.single as Note;
    expect(saved.id, 'n1');
    expect(saved.content, contains('xhi'));
  });

  testWidgets('setting a reminder shows it on the note straight away', (
    tester,
  ) async {
    const note = Note(id: 'n1', title: 'Groceries');
    var stored = note;
    when(() => notesRepo.getNote('n1')).thenAnswer((_) async => stored);
    when(() => notesRepo.setReminder(any(), any())).thenAnswer((
      invocation,
    ) async {
      stored = stored.copyWith(
        reminder: invocation.positionalArguments[1] as NoteReminder?,
      );
    });

    await pumpScreen(tester, note: note);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(LucideIcons.ellipsisVertical));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(LucideIcons.bell));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tomorrow'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    verify(() => notesRepo.setReminder('n1', any())).called(1);
    expect(find.byType(ReminderChip), findsOneWidget);
  });

  testWidgets('pinning saves only the pin', (tester) async {
    when(
      () => notesRepo.bulkSetPinned(any(), any()),
    ).thenAnswer((_) async => 1);

    await pumpScreen(
      tester,
      note: const Note(id: 'n1', title: 'Groceries'),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(LucideIcons.pin));
    await tester.pump(const Duration(seconds: 3));

    verify(() => notesRepo.bulkSetPinned(['n1'], true)).called(1);
    verifyNever(() => notesRepo.updateNote(any()));
  });

  group('a note shared for viewing', () {
    const note = Note(
      id: 'n1',
      title: 'Groceries',
      permission: NotePermission.viewer,
    );

    testWidgets('pins it for them without saving the note', (tester) async {
      when(
        () => notesRepo.bulkSetPinned(any(), any()),
      ).thenAnswer((_) async => 1);

      await pumpScreen(tester, note: note);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(LucideIcons.pin));
      await tester.pumpAndSettle();

      verify(() => notesRepo.bulkSetPinned(['n1'], true)).called(1);
      verifyNever(() => notesRepo.updateNote(any()));
    });

    testWidgets('sets a reminder for them', (tester) async {
      when(() => notesRepo.getNote('n1')).thenAnswer((_) async => note);
      when(() => notesRepo.setReminder(any(), any())).thenAnswer((_) async {});

      await pumpScreen(tester, note: note);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(LucideIcons.ellipsisVertical));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(LucideIcons.bell));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tomorrow'));
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      verify(() => notesRepo.setReminder('n1', any())).called(1);
      verifyNever(() => notesRepo.updateNote(any()));
    });
  });
}
