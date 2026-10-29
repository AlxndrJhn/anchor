import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/core/widgets/anchor_menu.dart';
import 'package:anchor/features/notes/presentation/editor/slash_menu.dart';
import 'package:anchor/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

List<String> labels(String query) => findSlashItems(
  query,
  _english,
).map((item) => item.labelIn(_english)).toList();

final _english = lookupAppLocalizations(const Locale('en'));

void main() {
  group('findSlashItems', () {
    test('shows the six used most before anything is typed', () {
      const common = [
        'Checklist',
        'Heading 1',
        'Bullet list',
        'Numbered list',
        'Quote',
        'Picture or audio',
      ];
      expect(labels(''), common);
      expect(labels('  '), common);
    });

    test('ranks a label that starts with the query first, then label '
        'words, then the other words', () {
      expect(labels('li'), [
        'Link',
        'Bullet list',
        'Numbered list',
        'Checklist',
      ]);
    });

    test('every typed word has to match', () {
      expect(labels('head 2'), ['Heading 2']);
      expect(labels('head 4'), isEmpty);
    });

    test('answers to its other words, in any case', () {
      expect(labels('todo'), ['Checklist']);
      expect(labels('H1'), ['Heading 1']);
      expect(labels('photo'), ['Picture or audio']);
    });

    test('finds nothing for words no item has', () {
      expect(labels('zz'), isEmpty);
    });
  });

  test('the menu shows every row that fits, else whole rows and half of '
      'the next, and two rows at least', () {
    // Rows are 44 tall, with 8 of padding above and below.
    expect(SlashMenu.heightFor(6, 500), 6 * 44 + 16);
    expect(SlashMenu.heightFor(6, 200), 3.5 * 44 + 16);
    expect(SlashMenu.heightFor(6, 0), 1.5 * 44 + 16);
    expect(SlashMenu.heightFor(2, 0), 2 * 44 + 16);
  });

  testWidgets('the menu shows every match, six before anything is typed', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomLeft,
            child: SlashMenu(
              items: findSlashItems('', _english),
              onPick: (_) {},
              space: 500,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MenuRow), findsNWidgets(6));
    expect(find.text('Picture or audio'), findsOneWidget);
  });
}
