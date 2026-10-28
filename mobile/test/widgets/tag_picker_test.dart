import 'dart:async';

import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/features/notes/data/repository/notes_repository.dart';
import 'package:anchor/features/notes/domain/note.dart';
import 'package:anchor/features/tags/domain/tag.dart';
import 'package:anchor/features/tags/presentation/tags_controller.dart';
import 'package:anchor/features/tags/presentation/widgets/tag_sheets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockNotesRepository extends Mock implements NotesRepository {}

/// Tags kept in memory; a created one shows in the list at once.
class _Tags extends TagsController {
  final _changes = StreamController<List<Tag>>();
  var _tags = [
    for (var i = 0; i < 30; i++)
      Tag(id: 't$i', name: 'Tag ${i.toString().padLeft(2, '0')}'),
  ];

  @override
  Stream<List<Tag>> build() {
    ref.onDispose(_changes.close);
    _changes.add(_tags);
    return _changes.stream;
  }

  @override
  Future<Tag> createTag(String name, {String? color}) async {
    final tag = Tag(id: 'new', name: name);
    _tags = [..._tags, tag];
    _changes.add(_tags);
    return tag;
  }
}

void main() {
  testWidgets('a tag created in the picker is scrolled into view', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1080, 2340)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final notes = _MockNotesRepository();
    when(() => notes.addTags(any(), any())).thenAnswer((_) async {});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tagsControllerProvider.overrideWith(_Tags.new),
          notesRepositoryProvider.overrideWithValue(notes),
          tagNoteCountsProvider.overrideWithValue(const {}),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  showTagPicker(context, const [Note(id: 'n1', title: 'Note')]),
              child: const Text('Tags'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Tags'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Zebra');
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    final row = find.text('Zebra');
    expect(row, findsOneWidget);
    final screen = tester.getRect(find.byType(MaterialApp));
    expect(screen.contains(tester.getCenter(row)), isTrue);
    expect(tester.getCenter(row).dy, lessThan(screen.bottom - 48));
    verify(() => notes.addTags(['n1'], ['new'])).called(1);
  });
}
