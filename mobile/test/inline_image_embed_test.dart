import 'dart:convert';
import 'dart:io';

import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/core/theme/tokens/anchor_tokens.dart';
import 'package:anchor/features/notes/data/repository/note_attachments_repository.dart';
import 'package:anchor/features/notes/domain/inline_image.dart';
import 'package:anchor/features/notes/domain/note_attachment.dart';
import 'package:anchor/features/notes/presentation/editor/editor_palette.dart';
import 'package:anchor/features/notes/presentation/editor/inline_image_embed.dart';
import 'package:anchor/features/notes/presentation/editor/rich_text_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mocktail/mocktail.dart';

class MockAttachmentsRepository extends Mock
    implements NoteAttachmentsRepository {}

/// Lets sheets and dialogs open or close; the loading shimmer never stops,
/// so pumpAndSettle would wait forever.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

final _plain = AnchorColors.light.notes['none']!;

final _palette = EditorPalette(
  muted: _plain.muted,
  surface: _plain.surface,
  border: _plain.border,
  background: _plain.bg,
  highlightFill: (name) => AnchorColors.light.highlights[name]!.fill,
  highlightInk: (name) => AnchorColors.light.highlights[name]!.ink!,
);

void main() {
  late MockAttachmentsRepository repo;
  late Directory tmp;
  late String picture;

  setUp(() {
    repo = MockAttachmentsRepository();
    tmp = Directory.systemTemp.createTempSync('inline');
    picture = '${tmp.path}/a.png';
    File(
      picture,
    ).writeAsBytesSync(img.encodePng(img.Image(width: 8, height: 6)));
    when(() => repo.watchAttachment('a')).thenAnswer(
      (_) => Stream.value(
        NoteAttachment(
          id: 'a',
          noteId: 'n1',
          type: AttachmentType.image,
          originalFilename: 'a.png',
          mimeType: 'image/png',
          fileSize: 1,
          localPath: picture,
        ),
      ),
    );
    when(() => repo.deleteAttachment(any(), any())).thenAnswer((_) async {});
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  Future<(RichTextEditorState, InlineImages)> pumpNote(
    WidgetTester tester, {
    InlineImage image = const InlineImage(id: 'a'),
  }) async {
    final images = InlineImages(repo: repo, noteId: () => 'n1');
    addTearDown(images.dispose);
    final focus = FocusNode();
    final scroll = ScrollController();
    addTearDown(focus.dispose);
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates:
            FlutterQuillLocalizations.localizationsDelegates,
        home: Scaffold(
          body: SingleChildScrollView(
            controller: scroll,
            child: RichTextEditor(
              initialContent: jsonEncode({
                'ops': [
                  {'insert': 'Hi\n'},
                  {
                    'insert': {InlineImage.embedType: image.encode()},
                  },
                  {'insert': '\nthere\n'},
                ],
              }),
              focusNode: focus,
              scrollController: scroll,
              palette: _palette,
              embedBuilders: [InlineImageEmbedBuilder(images)],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return (
      tester.state<RichTextEditorState>(find.byType(RichTextEditor)),
      images,
    );
  }

  InlineImage shown(RichTextEditorState editor) =>
      InlineImage.tryParse(editor.embedsOf(InlineImage.embedType).single)!;

  testWidgets('shows the attachment’s picture in the text', (tester) async {
    await pumpNote(tester);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('holding it offers what can be done with it', (tester) async {
    await pumpNote(tester);

    await tester.longPress(find.byType(Image));
    await settle(tester);

    for (final label in [
      'Retake',
      'Crop',
      'Mirror horizontally',
      'Mirror vertically',
      'Add caption',
      'Delete',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });

  testWidgets('a caption is kept with the picture and shown under it', (
    tester,
  ) async {
    final (editor, _) = await pumpNote(tester);

    await tester.longPress(find.byType(Image));
    await settle(tester);
    await tester.tap(find.text('Add caption'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'Our cat');
    await tester.tap(find.text('Save'));
    await settle(tester);
    await settle(tester);

    expect(shown(editor).caption, 'Our cat');
    expect(find.text('Our cat'), findsOneWidget);
  });

  testWidgets('Delete takes the picture and its attachment away', (
    tester,
  ) async {
    final (editor, _) = await pumpNote(tester);

    await tester.longPress(find.byType(Image));
    await settle(tester);
    await tester.tap(find.text('Delete'));
    await settle(tester);

    expect(editor.embedsOf(InlineImage.embedType), isEmpty);
    expect(editor.getPlainText(), 'Hi\nthere');
    verify(() => repo.deleteAttachment('n1', 'a')).called(1);
  });

  testWidgets('the handle resizes it while the note is edited', (tester) async {
    // A phone-sized screen, with the whole picture on it.
    tester.view
      ..physicalSize = const Size(400, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (editor, images) = await pumpNote(tester);
    final handle = find.byIcon(LucideIcons.moveDiagonal2);
    final before = tester.getSize(find.byType(Image)).width;

    images.editing.value = true;
    await settle(tester);
    await tester.drag(handle, Offset(-before / 2, 0));
    await settle(tester);

    final width = shown(editor).width!;
    expect(width, closeTo(0.5, 0.08));
    expect(
      tester.getSize(find.byType(Image)).width,
      closeTo(before * width, 2),
    );
  });

  testWidgets('a picture whose attachment is gone says so', (tester) async {
    when(
      () => repo.watchAttachment('gone'),
    ).thenAnswer((_) => Stream.value(null));
    await pumpNote(tester, image: const InlineImage(id: 'gone'));
    await tester.pump();

    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(LucideIcons.imageOff), findsOneWidget);
  });
}
