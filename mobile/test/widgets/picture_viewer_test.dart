import 'dart:async';

import 'package:anchor/core/files/image_text.dart';
import 'package:anchor/core/network/connectivity_provider.dart';
import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/features/notes/data/repository/note_attachments_repository.dart';
import 'package:anchor/features/notes/data/repository/picture_aspect_ratios.dart';
import 'package:anchor/features/notes/domain/note_attachment.dart';
import 'package:anchor/features/notes/presentation/widgets/image_text_view.dart';
import 'package:anchor/features/notes/presentation/widgets/picture_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAttachmentsRepository extends Mock
    implements NoteAttachmentsRepository {}

class FixedAspectRatios extends PictureAspectRatios {
  @override
  Future<double> measure(String attachmentId, String file) async => 1;
}

class Online extends Notifier<bool> {
  Online(this.initial);

  final bool initial;

  @override
  bool build() => initial;
}

const picture = NoteAttachment(
  id: 'a1',
  noteId: 'n1',
  type: AttachmentType.image,
  originalFilename: 'harbor.jpg',
  mimeType: 'image/jpeg',
  fileSize: 1200,
);

void main() {
  late MockAttachmentsRepository repo;

  setUp(() => repo = MockAttachmentsRepository());

  Future<void> openViewer(
    WidgetTester tester, {
    bool isOnline = true,
    ValueChanged<String>? onGrabText,
  }) async {
    final online = NotifierProvider<Online, bool>(() => Online(isOnline));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isOnlineProvider.overrideWith((ref) => ref.watch(online)),
          noteAttachmentsRepositoryProvider.overrideWithValue(repo),
          pictureAspectRatiosProvider.overrideWithValue(FixedAspectRatios()),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showPictureViewer(
                  context,
                  noteId: 'n1',
                  pictures: const [picture],
                  initial: 0,
                  canDelete: (_) => false,
                  onDelete: (_) {},
                  onGrabText: onGrabText,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  void download(Future<String> Function() answer) => when(
    () => repo.downloadAttachment('n1', 'a1', 'harbor.jpg'),
  ).thenAnswer((_) => answer());

  testWidgets('a picture that doesn’t download while online says so, and '
      'Try again downloads it again', (tester) async {
    download(() async => throw Exception('server unreachable'));
    await openViewer(tester);

    expect(find.text('Couldn’t load this picture'), findsOneWidget);
    expect(find.textContaining('back online'), findsNothing);

    final retry = Completer<String>();
    download(() => retry.future);
    await tester.tap(find.text('Try again'));
    await tester.pump();

    expect(find.text('Couldn’t load this picture'), findsNothing);
    verify(() => repo.downloadAttachment('n1', 'a1', 'harbor.jpg')).called(2);
  });

  testWidgets('offline, it waits for the connection', (tester) async {
    await openViewer(tester, isOnline: false);

    expect(
      find.text('This picture will show when you’re back online'),
      findsOneWidget,
    );
    expect(find.text('Try again'), findsNothing);
    verifyNever(() => repo.downloadAttachment(any(), any(), any()));
  });

  testWidgets('the picture has its name for screen readers', (tester) async {
    final semantics = tester.ensureSemantics();
    download(() async => '/nowhere/harbor.jpg');
    await openViewer(tester);

    expect(
      find.descendant(
        of: find.byType(PageView),
        matching: find.bySemanticsLabel('harbor.jpg'),
      ),
      findsOneWidget,
    );
    semantics.dispose();
  });

  group('Grab image text', () {
    tearDown(() => debugImageTextReader = null);

    ImageWord word(String text, double left, int line) => ImageWord(
      text: text,
      rect: Rect.fromLTWH(left, line * 60.0, 150, 40),
      line: line,
      block: 0,
    );

    final harbor = ImageText([
      word('Harbor', 0, 0),
      word('Road', 200, 0),
      word('12', 400, 0),
      word('Open', 0, 1),
      word('9-5', 200, 1),
    ], imageSize: const Size(600, 200));

    testWidgets('shows the words found to pick from; Select all and Insert in '
        'note add them to the note and close', (tester) async {
      download(() async => '/nowhere/harbor.jpg');
      String? read;
      debugImageTextReader = (path) async {
        read = path;
        return harbor;
      };
      String? added;
      await openViewer(tester, onGrabText: (text) => added = text);

      await tester.tap(find.bySemanticsLabel('Grab image text'));
      await tester.pumpAndSettle();

      expect(read, '/nowhere/harbor.jpg');
      expect(find.byType(ImageTextView), findsOneWidget);
      expect(find.text('Select text'), findsOneWidget);
      expect(added, isNull);

      await tester.tap(find.bySemanticsLabel('Select all'));
      await tester.pump();
      expect(find.text('5 words selected'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Insert in note'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(added, 'Harbor Road 12\nOpen 9-5');
      expect(find.byType(ImageTextView), findsNothing);
      expect(find.byType(PageView), findsNothing);
      await tester.pumpAndSettle();
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('closing the picked text adds nothing and keeps the picture', (
      tester,
    ) async {
      download(() async => '/nowhere/harbor.jpg');
      debugImageTextReader = (_) async => harbor;
      String? added;
      await openViewer(tester, onGrabText: (text) => added = text);

      await tester.tap(find.bySemanticsLabel('Grab image text'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Close').last);
      await tester.pumpAndSettle();

      expect(added, isNull);
      expect(find.byType(ImageTextView), findsNothing);
      expect(find.byType(PageView), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('a picture with no text says so and stays open', (
      tester,
    ) async {
      download(() async => '/nowhere/harbor.jpg');
      debugImageTextReader = (_) async => const ImageText([]);
      String? added;
      await openViewer(tester, onGrabText: (text) => added = text);

      await tester.tap(find.bySemanticsLabel('Grab image text'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(added, isNull);
      expect(find.byType(ImageTextView), findsNothing);
      expect(find.byType(PageView), findsOneWidget);
      expect(
        find.textContaining('No text found', findRichText: true),
        findsOneWidget,
      );
      await tester.pumpAndSettle();
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('where the note can\'t be edited, the text can be copied but '
        'not inserted', (tester) async {
      download(() async => '/nowhere/harbor.jpg');
      debugImageTextReader = (_) async => harbor;
      await openViewer(tester);

      await tester.tap(find.bySemanticsLabel('Grab image text'));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Copy'), findsOneWidget);
      expect(find.bySemanticsLabel('Insert in note'), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('is not offered where pictures can\'t be read', (tester) async {
      download(() async => '/nowhere/harbor.jpg');
      await openViewer(tester, onGrabText: (_) {});

      expect(find.bySemanticsLabel('Grab image text'), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });
}
