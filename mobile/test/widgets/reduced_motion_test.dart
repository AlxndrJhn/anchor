import 'dart:async';

import 'package:anchor/core/motion/page_transitions.dart';
import 'package:anchor/core/network/connectivity_provider.dart';
import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/core/widgets/page_bar.dart';
import 'package:anchor/features/notes/data/repository/note_attachments_repository.dart';
import 'package:anchor/features/notes/domain/note_attachment.dart';
import 'package:anchor/features/notes/presentation/widgets/note_bar.dart';
import 'package:anchor/features/notes/presentation/widgets/note_surface.dart';
import 'package:anchor/features/notes/presentation/widgets/picture_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAttachmentsRepository extends Mock
    implements NoteAttachmentsRepository {}

void main() {
  void reduceMotion(WidgetTester tester) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(reduceMotion: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('with reduced motion, a page on ${platform.name} appears at '
        'once', (tester) async {
      reduceMotion(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            platform: platform,
            pageTransitionsTheme: PageTransitionsTheme(
              builders: {platform: const AnchorPageTransitionsBuilder()},
            ),
          ),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ColoredBox(
                    key: ValueKey('next'),
                    color: Colors.teal,
                    child: SizedBox.expand(),
                  ),
                ),
              ),
              child: const Text('Next'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Next'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      expect(tester.getTopLeft(find.byKey(const ValueKey('next'))).dx, 0);
    });
  }

  testWidgets('with reduced motion, a loading picture doesn’t shimmer', (
    tester,
  ) async {
    reduceMotion(tester);
    final repo = MockAttachmentsRepository();
    when(
      () => repo.downloadAttachment(any(), any(), any()),
    ).thenAnswer((_) => Completer<String>().future);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isOnlineProvider.overrideWithValue(true),
          noteAttachmentsRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) => Center(
              child: PictureTile(
                attachment: const NoteAttachment(
                  id: 'a1',
                  noteId: 'n1',
                  type: AttachmentType.image,
                  originalFilename: 'harbor.jpg',
                  mimeType: 'image/jpeg',
                  fileSize: 1200,
                ),
                appearance: NoteAppearance.of(context, null),
                onOpen: () {},
                onDelete: null,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('the On this phone badge is read once', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => NoteBar(
            appearance: NoteAppearance.of(context, null),
            scrollOffset: ScrollOffset(ScrollController()),
            reminder: null,
            isUnsynced: true,
            isTrashed: false,
            isReadOnly: false,
            onBack: () {},
            onHistory: () {},
            onBackground: () {},
            onReminder: () {},
            onMore: () {},
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Changes not synced yet'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('On this phone')), findsNothing);
    semantics.dispose();
  });
}
