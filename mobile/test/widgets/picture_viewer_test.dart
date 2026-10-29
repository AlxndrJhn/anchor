import 'dart:async';

import 'package:anchor/core/network/connectivity_provider.dart';
import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/features/notes/data/repository/note_attachments_repository.dart';
import 'package:anchor/features/notes/data/repository/picture_aspect_ratios.dart';
import 'package:anchor/features/notes/domain/note_attachment.dart';
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

  Future<void> openViewer(WidgetTester tester, {bool isOnline = true}) async {
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
}
