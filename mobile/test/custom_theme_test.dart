import 'dart:convert';

import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/core/theme/custom_theme.dart';
import 'package:anchor/core/theme/tokens/app_dimensions.dart';
import 'package:anchor/core/theme/tokens/app_schemes.dart';
import 'package:anchor/core/theme/tokens/app_style.dart';
import 'package:anchor/features/settings/data/repository/preferences_repository.dart';
import 'package:anchor/features/settings/presentation/controllers/editor_preferences_controller.dart';
import 'package:anchor/features/settings/presentation/controllers/theme_preferences_controller.dart';
import 'package:anchor/features/settings/presentation/custom_theme_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

List<String> errorsOf(String text) => parseCustomTheme(text).errors;

class FakePreferences extends PreferencesRepository {
  FakePreferences() : super(const FlutterSecureStorage());

  String? customTheme;

  @override
  Future<void> setCustomTheme(String? json) async => customTheme = json;
}

void main() {
  group('parseCustomTheme', () {
    test('reads a valid theme', () {
      final result = parseCustomTheme(
        jsonEncode({
          'name': 'Mine',
          'light': {'background': '#FFF', 'accent': '#EF8354'},
          'dark': {'card': '#11223380'},
        }),
      );
      expect(result.isOk, isTrue);
      final theme = result.theme!;
      expect(theme.name, 'Mine');
      expect(theme.light, {
        'background': const Color(0xFFFFFFFF),
        'accent': const Color(0xFFEF8354),
      });
      expect(theme.dark, {'card': const Color(0x80112233)});
      expect(
        theme.encode(),
        '{"name":"Mine","light":{"background":"#ffffff","accent":"#ef8354"},'
        '"dark":{"card":"#11223380"}}',
      );
    });

    test('takes just one mode', () {
      final theme = parseCustomTheme('{"dark": {"background": "#000"}}').theme;
      expect(theme?.light, isNull);
      expect(theme?.dark, {'background': const Color(0xFF000000)});
    });

    test('names an unknown key and guesses what was meant', () {
      final errors = errorsOf('{"dark": {"backgroud": "#000"}}');
      expect(errors, hasLength(1));
      expect(errors.single, startsWith('dark.backgroud: unknown key'));
      expect(errors.single, contains('did you mean "background"?'));
      expect(
        errorsOf('{"drak": {}, "light": {}}').first,
        startsWith('drak: unknown key (did you mean "dark"?)'),
      );
    });

    test('says which colour is wrong and why', () {
      expect(errorsOf('{"light": {"card": "#12"}}'), [
        'light.card: "#12" is not a colour; use #rgb, #rrggbb or #rrggbbaa',
      ]);
      expect(
        errorsOf('{"light": {"card": "red"}}').single,
        startsWith('light.card:'),
      );
      expect(
        errorsOf('{"light": {"card": 255}}').single,
        startsWith('light.card: 255 is not a colour'),
      );
    });

    test('wants light or dark', () {
      expect(errorsOf('{"name": "Empty"}'), [
        'Give at least one of "light" or "dark"',
      ]);
      expect(errorsOf('{}'), ['Give at least one of "light" or "dark"']);
    });

    test('lists every problem at once', () {
      final errors = errorsOf(
        '{"name": 3, "light": [], "dark": {"text": "#fff", "card": "#zzz"}}',
      );
      expect(errors, hasLength(4));
      expect(errors[0], 'name: must be a string');
      expect(errors[1], 'light: must be an object of colours');
      expect(errors[2], startsWith('dark.text: unknown key'));
      expect(errors[3], startsWith('dark.card: "#zzz" is not a colour'));
    });

    test("rejects what isn't JSON or isn't an object", () {
      expect(errorsOf('{dark:').single, startsWith('Not valid JSON:'));
      expect(errorsOf('[]').single, contains('must be a JSON object'));
    });
  });

  group('colours and merging', () {
    test('accepts #rgb, #rrggbb and #rrggbbaa only', () {
      expect(parseThemeColor('#AbC'), const Color(0xFFAABBCC));
      expect(parseThemeColor('#a1b2c3'), const Color(0xFFA1B2C3));
      expect(parseThemeColor('#a1b2c3d4'), const Color(0xD4A1B2C3));
      for (final bad in ['abc', '#abcd', '#abcde', '#ggg', '#a1b2c3d', '']) {
        expect(parseThemeColor(bad), isNull, reason: bad);
      }
      expect(themeColorToHex(const Color(0xFFA1B2C3)), '#a1b2c3');
      expect(themeColorToHex(const Color(0x80A1B2C3)), '#a1b2c380');
    });

    test("falls back to the chosen scheme for what's missing", () {
      final nord = schemeById('nord')!.dark;
      final theme = parseCustomTheme('{"dark": {"background": "#000"}}').theme!;
      final merged = theme.merge(nord, Brightness.dark);
      expect(merged.background, const Color(0xFF000000));
      expect(
        merged.toMap()..remove('background'),
        nord.toMap()..remove('background'),
      );
      // No light colours: light mode keeps the scheme as it is.
      expect(
        theme.merge(schemeById('nord')!.light, Brightness.light).toMap(),
        schemeById('nord')!.light.toMap(),
      );
    });

    test('copies the current theme as JSON that reads back', () {
      final custom = parseCustomTheme('{"dark": {"accent": "#b8bb26"}}').theme;
      final json = themeAsJson(schemeById('gruvbox')!, custom);
      final result = parseCustomTheme(json);
      expect(result.errors, isEmpty);
      expect(result.theme!.name, 'Gruvbox');
      expect(result.theme!.dark!.keys, SchemePalette.fields);
      expect(result.theme!.dark!['accent'], const Color(0xFFB8BB26));
      expect(result.theme!.dark!['background'], const Color(0xFF282828));
      expect(result.theme!.light!['background'], const Color(0xFFFBF1C7));
    });
  });

  group('the app theme', () {
    test('a custom theme colours the theme over the scheme', () {
      final custom = parseCustomTheme(
        '{"dark": {"background": "#101010", "foreground": "#fafafa"}}',
      ).theme!;
      final dark = AppTheme.dark(
        DisplayDensity.standard,
        'nord',
        AppStyle.standard,
        custom,
      );
      expect(dark.scaffoldBackgroundColor, const Color(0xFF101010));
      expect(dark.colorScheme.onSurface, const Color(0xFFFAFAFA));
      // The rest is Nord's.
      expect(dark.cardTheme.color, schemeById('nord')!.dark.card);
      // Light mode has no custom colours, so it is plain Nord.
      final light = AppTheme.light(
        DisplayDensity.standard,
        'nord',
        AppStyle.standard,
        custom,
      );
      expect(
        light.scaffoldBackgroundColor,
        schemeById('nord')!.light.background,
      );
    });

    test("over Anchor, a custom theme falls back to Anchor's colours", () {
      final custom = parseCustomTheme('{"light": {"accent": "#ff0000"}}').theme;
      final theme = AppTheme.light(
        DisplayDensity.standard,
        anchorSchemeId,
        AppStyle.standard,
        custom,
      );
      expect(theme.colorScheme.tertiary, const Color(0xFFFF0000));
      expect(theme.scaffoldBackgroundColor, anchorScheme.light.background);
    });

    test('Lo-fi keeps its greys over a custom theme', () {
      final custom = parseCustomTheme(
        '{"light": {"background": "#f00"}}',
      ).theme;
      final theme = AppTheme.light(
        DisplayDensity.standard,
        'nord',
        AppStyle.lofi,
        custom,
      );
      expect(theme.scaffoldBackgroundColor, lofiScheme.light.background);
    });
  });

  testWidgets('Settings: apply, see errors, copy and reset', (tester) async {
    final prefs = FakePreferences();
    String? clipboard;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    final container = ProviderContainer(
      overrides: [preferencesRepositoryProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: SingleChildScrollView(child: CustomThemeEditor()),
          ),
        ),
      ),
    );

    final field = find.byKey(const Key('custom-theme-json'));
    await tester.enterText(field, '{"dark": {"bakground": "#000"}}');
    await tester.pump();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(find.textContaining('dark.bakground: unknown key'), findsOneWidget);
    expect(container.read(customThemeControllerProvider), isNull);

    await tester.enterText(
      field,
      '{"name": "Ink", "dark": {"background": "#000"}}',
    );
    await tester.pump();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(find.textContaining('unknown key'), findsNothing);
    expect(container.read(customThemeControllerProvider)?.name, 'Ink');
    expect(prefs.customTheme, '{"name":"Ink","dark":{"background":"#000000"}}');

    await tester.tap(find.text('Copy current theme as JSON'));
    await tester.pumpAndSettle();
    expect(clipboard, isNotNull);
    final copied = parseCustomTheme(clipboard!).theme!;
    expect(copied.name, 'Ink');
    expect(copied.dark!['background'], const Color(0xFF000000));
    expect(copied.light!['background'], anchorScheme.light.background);

    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(container.read(customThemeControllerProvider), isNull);
    expect(prefs.customTheme, isNull);
  });
}
