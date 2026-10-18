import 'package:anchor/core/network/server_config_provider.dart';
import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/core/theme/display_density.dart';
import 'package:anchor/core/widgets/anchor_dialog.dart';
import 'package:anchor/core/widgets/app_buttons.dart';
import 'package:anchor/core/widgets/app_text_field.dart';
import 'package:anchor/core/widgets/grouped_list.dart';
import 'package:anchor/core/widgets/page_bar.dart';
import 'package:anchor/core/widgets/platform_switch.dart';
import 'package:anchor/core/widgets/selection_bar.dart';
import 'package:anchor/core/widgets/switch_row.dart';
import 'package:anchor/features/notes/domain/note.dart';
import 'package:anchor/features/notes/presentation/widgets/note_card.dart';
import 'package:anchor/features/tags/presentation/tags_controller.dart';
import 'package:anchor/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

final _english = lookupAppLocalizations(const Locale('en'));

void main() {
  Widget app(DisplayDensity density, Widget child) => ProviderScope(
    overrides: [
      tagsControllerProvider.overrideWith(TagsController.new),
      serverUrlProvider.overrideWithValue('https://example.test'),
    ],
    child: MaterialApp(
      theme: AppTheme.light(density),
      home: Scaffold(
        body: Align(alignment: Alignment.topCenter, child: child),
      ),
    ),
  );

  for (final (density, control, space8, space12, space24) in [
    (DisplayDensity.standard, 52.0, 8.0, 12.0, 24.0),
    (DisplayDensity.compact, 44.0, 4.0, 8.0, 16.0),
  ]) {
    group(density.labelIn(_english), () {
      testWidgets('the bar, buttons, fields and rows are $control tall', (
        tester,
      ) async {
        await tester.pumpWidget(
          app(
            density,
            Column(
              children: [
                const PageBar(key: Key('bar'), title: Text('Notes')),
                AppButton(
                  key: const Key('button'),
                  label: 'Save',
                  onPressed: () {},
                ),
                AppButton(
                  key: const Key('medium'),
                  label: 'Cancel',
                  size: AppButtonSize.medium,
                  onPressed: () {},
                ),
                const AppTextField(key: Key('field'), hint: 'Name'),
                const GroupedList(
                  children: [GroupedListTile(key: Key('row'), label: 'Theme')],
                ),
                SelectionBar(
                  key: const Key('selection'),
                  enabled: true,
                  actions: [
                    SelectionAction(
                      icon: LucideIcons.pin,
                      label: 'Pin',
                      onPressed: () {},
                    ),
                  ],
                ),
              ],
            ),
          ),
        );

        double heightOf(String key) =>
            tester.getSize(find.byKey(Key(key))).height;
        expect(heightOf('bar'), control);
        expect(heightOf('button'), control);
        expect(heightOf('medium'), 44);
        expect(heightOf('field'), control);
        expect(heightOf('row'), control);
        expect(heightOf('selection'), control + space12);
      });

      testWidgets('a switch row is $control tall, its track on the row inset', (
        tester,
      ) async {
        await tester.pumpWidget(
          app(
            density,
            GroupedList(
              children: [
                SwitchRow(
                  key: const Key('switch'),
                  label: 'Sync',
                  value: false,
                  onChanged: (_) {},
                ),
              ],
            ),
          ),
        );
        final row = tester.getRect(find.byKey(const Key('switch')));
        final track = tester.getRect(find.byType(PlatformSwitch));
        expect(row.height, control);
        expect(track.right, row.right - GroupedListTile.inset);
        expect(track.center.dy, row.center.dy);
      }, variant: TargetPlatformVariant.mobile());

      testWidgets('a section label sits $space8 over its group', (
        tester,
      ) async {
        await tester.pumpWidget(
          app(
            density,
            const Section(
              label: 'Appearance',
              child: SizedBox(key: Key('group'), height: 40),
            ),
          ),
        );

        final label = tester.getRect(find.text('APPEARANCE'));
        final group = tester.getRect(find.byKey(const Key('group')));
        expect(group.top - label.bottom, space8);
      });

      testWidgets('a dialog keeps its message $space24 over the buttons', (
        tester,
      ) async {
        await tester.pumpWidget(
          app(
            density,
            Builder(
              builder: (context) => TextButton(
                onPressed: () => showAnchorDialog(
                  context,
                  title: 'Delete note?',
                  message: 'It goes for good.',
                  confirmLabel: 'Delete',
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        final message = tester.getRect(find.text('It goes for good.'));
        final buttons = tester.getRect(find.byType(AppButton).first);
        expect(buttons.top - message.bottom, space24);
      });
    });
  }

  testWidgets('Compact shows fewer lines on a card', (tester) async {
    final lines = [for (var i = 1; i <= 8; i++) 'Line $i'].join(r'\n');
    final note = Note(
      id: 'n1',
      title: 'Plan',
      content: '{"ops":[{"insert":"$lines\\n"}]}',
    );
    for (final (density, shown) in [
      (DisplayDensity.standard, 6),
      (DisplayDensity.compact, 4),
    ]) {
      await tester.pumpWidget(
        app(
          density,
          SizedBox(
            width: 180,
            child: NoteCard(note: note, tags: const []),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining(RegExp(r'^Line \d$'), findRichText: true),
        findsNWidgets(shown),
      );
    }
  });
}
