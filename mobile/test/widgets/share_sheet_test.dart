import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/core/widgets/anchor_sheet.dart';
import 'package:anchor/core/widgets/pill.dart';
import 'package:anchor/features/share_target/data/share_sheet_channel.dart';
import 'package:anchor/features/share_target/domain/share_context.dart';
import 'package:anchor/features/share_target/presentation/share_sheet.dart';
import 'package:anchor/features/tags/domain/tag.dart';
import 'package:anchor/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _signedIn = ShareContext(
  userId: 'u1',
  tags: [
    Tag(id: 't1', name: 'Bread', color: '#c2410c'),
    Tag(id: 't2', name: 'Trips', color: '#0f766e'),
  ],
);

void main() {
  late List<ShareDraft> saved;
  late int openedApp;
  late Object? result;

  setUp(() {
    saved = [];
    openedApp = 0;
    result = 'open';
  });

  Future<void> show(
    WidgetTester tester,
    Map<String, Object?> share, {
    ShareContext context = _signedIn,
  }) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final intake = intakeFromMap(share);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (home) => TextButton(
            onPressed: () async {
              result = await showAnchorSheet<bool>(
                home,
                builder: (_) => ShareSheet(
                  intake: intake,
                  shareContext: context,
                  onSave: (draft) async => saved.add(draft),
                  onOpenApp: () => openedApp++,
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('a link from a browser shows its page title and the link, '
      'and saves both', (tester) async {
    await show(tester, {
      'title': 'Basic sourdough',
      'text': 'https://www.bread.io/sourdough',
    });

    expect(find.text('New note'), findsOneWidget);
    expect(find.text('Basic sourdough'), findsOneWidget);
    expect(find.text('bread.io'), findsOneWidget);
    expect(find.text('https://www.bread.io/sourdough'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(saved.single.title, 'Basic sourdough');
    expect(saved.single.text, '');
    expect(saved.single.link, 'https://www.bread.io/sourdough');
    expect(result, isTrue);
  });

  testWidgets('tags are picked with a tap and saved in name order', (
    tester,
  ) async {
    await show(tester, {'text': 'Feed the starter'});

    await tester.tap(find.widgetWithText(PillButton, 'Trips'));
    await tester.tap(find.widgetWithText(PillButton, 'Bread'));
    await tester.tap(find.widgetWithText(PillButton, 'Trips'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(saved.single.tagIds, ['t1']);
    expect(saved.single.text, 'Feed the starter');
  });

  testWidgets('a picture is waited for before saving, and one taken out '
      'is left out', (tester) async {
    await show(tester, {
      'staging': '/nowhere',
      'files': [
        {'id': '0', 'kind': 'picture', 'name': 'a.jpg', 'file': '0.jpg'},
        {'id': '1', 'kind': 'audio', 'name': 'Voice 12.ogg', 'file': '1.ogg'},
      ],
    });

    expect(find.text('Voice 12'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Remove a.jpg'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(
      [for (final file in saved.single.files) file.name],
      ['Voice 12.ogg'],
    );
  });

  testWidgets('says which files were left out', (tester) async {
    await show(tester, {
      'text': 'Holiday',
      'skipped': {'unsupported': 2},
    });
    expect(
      find.text('2 files can’t be added. Anchor adds pictures and audio.'),
      findsOneWidget,
    );
  });

  testWidgets('with nothing Anchor can keep, it says so and only closes', (
    tester,
  ) async {
    await show(tester, {
      'skipped': {'tooBig': 1},
    });

    expect(
      find.text('1 file is over 50 MB, so it can’t be added.'),
      findsOneWidget,
    );
    expect(find.text('Save'), findsNothing);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });

  testWidgets('signed out, it asks to sign in and can open the app', (
    tester,
  ) async {
    await show(tester, {'text': 'Hello'}, context: const ShareContext());

    expect(
      find.text('Sign in to Anchor to save what you share.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Open Anchor'));
    expect(openedApp, 1);
    expect(saved, isEmpty);
  });

  testWidgets('Save waits for something to save', (tester) async {
    await show(tester, {
      'files': [
        {'id': '0', 'kind': 'picture', 'name': 'a.jpg', 'file': '0.jpg'},
      ],
    });
    await tester.tap(find.bySemanticsLabel('Remove a.jpg'));
    await tester.pump();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(saved, isEmpty);

    await tester.enterText(find.byType(TextField).first, 'Just a title');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(saved.single.title, 'Just a title');
  });
}
