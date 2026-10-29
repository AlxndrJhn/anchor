import 'dart:math' as math;

import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/core/widgets/frosted_glass.dart';
import 'package:anchor/features/notes/presentation/widgets/note_surface.dart';
import 'package:anchor/features/notes/presentation/widgets/version_diff_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final (name, theme) in [
    ('light', AppTheme.light()),
    ('dark', AppTheme.dark()),
  ]) {
    for (final background in ['color_teal', 'color_blue', 'color_green']) {
      testWidgets('on a $background note in $name, a removed line stays red '
          'and an added one green', (tester) async {
        late DiffColors colors;
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Builder(
              builder: (context) {
                colors = DiffColors.of(
                  context,
                  NoteAppearance.of(context, background),
                );
                return const SizedBox();
              },
            ),
          ),
        );
        final removed = colors.removedLine;
        final added = colors.addedLine;
        expect(removed.r, greaterThan(math.max(removed.g, removed.b)));
        expect(added.g, greaterThan(math.max(added.r, added.b)));
      });
    }
  }

  testWidgets('glass that can\'t blur, like over the keyboard, is opaque', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: MediaQuery(
          data: const MediaQueryData(viewInsets: EdgeInsets.only(bottom: 300)),
          child: const Center(
            child: FrostedGlass(child: SizedBox(width: 200, height: 52)),
          ),
        ),
      ),
    );
    final fills = [
      for (final element
          in find
              .descendant(
                of: find.byType(FrostedGlass),
                matching: find.byType(DecoratedBox),
              )
              .evaluate())
        if (((element.renderObject! as RenderDecoratedBox).decoration
                    as BoxDecoration)
                .color
            case final color?)
          color.a,
    ];
    expect(fills, contains(1.0));
  });
}
