import 'package:anchor/core/theme/anchor_density.dart';
import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/core/theme/display_density.dart';
import 'package:anchor/core/theme/tokens/anchor_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppTheme', () {
    for (final (name, build, colors) in [
      ('light', AppTheme.light, AnchorColors.light),
      ('dark', AppTheme.dark, AnchorColors.dark),
    ]) {
      group(name, () {
        testWidgets('carries the matching colors and density', (tester) async {
          final theme = build();
          expect(theme.extension<AnchorColors>(), colors);
          expect(theme.extension<AnchorDensity>(), AnchorDensity.standard);
        });

        testWidgets('color scheme brightness matches the theme', (
          tester,
        ) async {
          final theme = build();
          expect(theme.colorScheme.brightness, theme.brightness);
        });

        testWidgets('page background is the scaffold background', (
          tester,
        ) async {
          final theme = build();
          expect(theme.scaffoldBackgroundColor, colors.appPage);
          expect(theme.scaffoldBackgroundColor, theme.colorScheme.surface);
        });

        testWidgets('the surface ramp stays distinct from the page', (
          tester,
        ) async {
          final colorScheme = build().colorScheme;
          final ramp = {
            colorScheme.surfaceContainerLowest,
            colorScheme.surfaceContainerLow,
            colorScheme.surfaceContainer,
            colorScheme.surfaceContainerHigh,
            colorScheme.surfaceContainerHighest,
          };
          expect(ramp.length, 5);
          expect(ramp, isNot(contains(colorScheme.surface)));
        });

        testWidgets('text and icons use the text color', (tester) async {
          final theme = build();
          expect(theme.colorScheme.onSurface, colors.appText);
          expect(theme.iconTheme.color, colors.appText);
        });

        testWidgets('text fields are bare inside the box each one draws', (
          tester,
        ) async {
          final fields = build().inputDecorationTheme;
          expect(fields.isCollapsed, isTrue);
          expect(fields.border, InputBorder.none);
          expect(fields.filled, isFalse);
        });

        testWidgets('field hints use the muted color', (tester) async {
          expect(
            build().inputDecorationTheme.hintStyle?.color,
            colors.appMuted,
          );
        });

        testWidgets('nothing ripples on tap', (tester) async {
          expect(build().splashFactory, NoSplash.splashFactory);
        });
      });
    }

    testWidgets('light and dark are actually different', (tester) async {
      expect(
        AppTheme.light().scaffoldBackgroundColor,
        isNot(AppTheme.dark().scaffoldBackgroundColor),
      );
    });

    testWidgets('each brightness/density pair is built once and cached', (
      tester,
    ) async {
      expect(identical(AppTheme.light(), AppTheme.light()), isTrue);
      expect(
        identical(
          AppTheme.light(DisplayDensity.compact),
          AppTheme.light(DisplayDensity.compact),
        ),
        isTrue,
      );
      expect(
        identical(AppTheme.light(), AppTheme.light(DisplayDensity.compact)),
        isFalse,
      );
    });

    testWidgets('density selects the matching extension', (tester) async {
      for (final density in DisplayDensity.values) {
        expect(
          AppTheme.light(density).extension<AnchorDensity>(),
          AnchorDensity.of(density),
        );
        expect(
          AppTheme.dark(density).extension<AnchorDensity>()!.isCompact,
          density == DisplayDensity.compact,
        );
      }
    });
  });
}
