import 'dart:io';

import 'package:anchor/core/network/connectivity_provider.dart';
import 'package:anchor/core/network/server_config_provider.dart';
import 'package:anchor/core/storage/storage_keys.dart';
import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/core/theme/app_typography.dart';
import 'package:anchor/core/theme/context_extensions.dart';
import 'package:anchor/core/theme/custom_theme.dart';
import 'package:anchor/core/theme/display_density.dart';
import 'package:anchor/core/theme/note_typography.dart';
import 'package:anchor/core/theme/style_typography.dart';
import 'package:anchor/core/theme/tokens/anchor_tokens.dart';
import 'package:anchor/core/theme/tokens/app_schemes.dart';
import 'package:anchor/core/theme/tokens/app_style.dart';
import 'package:anchor/core/widgets/grouped_list.dart';
import 'package:anchor/features/auth/domain/oidc_config.dart';
import 'package:anchor/features/auth/domain/user.dart';
import 'package:anchor/features/auth/presentation/auth_controller.dart';
import 'package:anchor/features/auth/presentation/oidc_config_provider.dart';
import 'package:anchor/features/notes/presentation/widgets/note_surface.dart';
import 'package:anchor/features/server/data/server_info_provider.dart';
import 'package:anchor/features/settings/presentation/settings_screen.dart';
import 'package:anchor/features/settings/presentation/theme_preferences_controller.dart';
import 'package:anchor/features/share_target/domain/share_context.dart';
import 'package:anchor/features/sync/data/sync_compatibility.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

ThemeData _light(String scheme, [AppStyle style = AppStyle.standard]) =>
    AppTheme.light(
      DisplayDensity.standard,
      NoteFont.sans,
      NoteTextSize.standard,
      scheme,
      style,
    );

ThemeData _dark(String scheme, [AppStyle style = AppStyle.standard]) =>
    AppTheme.dark(
      DisplayDensity.standard,
      NoteFont.sans,
      NoteTextSize.standard,
      scheme,
      style,
    );

/// A grouped list and a line of text, in [scheme] and [style].
class _Host extends StatelessWidget {
  const _Host({required this.scheme, required this.style});

  final String scheme;
  final AppStyle style;

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: _light(scheme, style),
    themeAnimationStyle: AnimationStyle.noAnimation,
    builder: (context, child) => StyleTypography(style: style, child: child!),
    home: const Scaffold(
      body: Column(
        children: [
          GroupedList(children: [GroupedListTile(label: 'Row')]),
          _PlainText(),
        ],
      ),
    ),
  );
}

/// Depends on nothing in the theme: only [StyleTypography] rebuilds it.
class _PlainText extends StatelessWidget {
  const _PlainText();

  @override
  Widget build(BuildContext context) => Text('Plain', style: AppTypography.row);
}

class _SignedOut extends AuthController {
  @override
  Future<User?> build() async => null;
}

/// Settings in the scheme and style it picks.
class _SettingsApp extends ConsumerWidget {
  const _SettingsApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = ref.watch(colorSchemeControllerProvider);
    final style = ref.watch(appStyleControllerProvider);
    final custom = ref.watch(customThemeControllerProvider);
    final highContrast = ref.watch(highContrastControllerProvider);
    return MaterialApp(
      theme: AppTheme.light(
        DisplayDensity.standard,
        NoteFont.sans,
        NoteTextSize.standard,
        scheme,
        style,
        custom,
        highContrast,
      ),
      themeAnimationStyle: AnimationStyle.noAnimation,
      builder: (context, child) => StyleTypography(style: style, child: child!),
      home: const SettingsScreen(),
    );
  }
}

BoxDecoration _groupOf(WidgetTester tester, Finder within) =>
    tester
            .widget<DecoratedBox>(
              find
                  .descendant(of: within, matching: find.byType(DecoratedBox))
                  .first,
            )
            .decoration
        as BoxDecoration;

String? _familyOf(WidgetTester tester, String text) => tester
    .widget<RichText>(
      find.descendant(of: find.text(text), matching: find.byType(RichText)),
    )
    .text
    .style
    ?.fontFamily;

Color _textColorOf(WidgetTester tester, String text) => tester
    .widget<RichText>(
      find.descendant(of: find.text(text), matching: find.byType(RichText)),
    )
    .text
    .style!
    .color!;

void main() {
  tearDown(() => AppTypography.useStyle(AppStyle.standard));

  test('style ids round-trip and fall back to Default', () {
    for (final style in AppStyle.values) {
      expect(AppStyle.fromId(style.id), style);
    }
    expect(AppStyle.fromId('nope'), AppStyle.standard);
    expect(AppStyle.fromId(null), AppStyle.standard);
  });

  test('every scheme id is unique and found', () {
    final ids = appSchemes.map((s) => s.id).toSet();
    expect(ids.length, appSchemes.length);
    expect(ids, isNot(contains(anchorSchemeId)));
    for (final id in ids) {
      expect(schemeById(id)?.id, id);
    }
    expect(schemeById(anchorSchemeId), isNull);
  });

  test('a scheme colours the theme; Lo-fi uses its own greys', () {
    final nord = schemeById('nord')!;
    final theme = _dark('nord');
    final colors = theme.extension<AnchorColors>()!;
    expect(theme.scaffoldBackgroundColor, nord.dark.background);
    expect(theme.colorScheme.onSurface, nord.dark.foreground);
    expect(colors.appPage, nord.dark.background);
    expect(colors.appSurface, nord.dark.card);
    expect(colors.appText, nord.dark.foreground);
    expect(colors.accentStrong, nord.dark.accentStrong);
    expect(colors.statusDanger, nord.dark.destructive);
    // Plain notes take the scheme's card colour; coloured notes keep theirs.
    expect(colors.notes['none']!.bg, nord.dark.card);
    expect(colors.notes['yellow'], AnchorColors.dark.notes['yellow']);

    final lofi = _light('nord', AppStyle.lofi);
    expect(lofi.scaffoldBackgroundColor, lofiScheme.light.background);
    expect(lofi.extension<AnchorStyle>()!.plainNotes, isTrue);
  });

  test('Anchor with Default keeps the original look', () {
    final theme = AppTheme.light();
    expect(theme.extension<AnchorColors>(), AnchorColors.light);
    final style = theme.extension<AnchorStyle>()!;
    expect(style.style, AppStyle.standard);
    expect(style.pattern, isNull);
    expect(
      style.corners(AnchorTokens.radiusCard),
      BorderRadius.circular(AnchorTokens.radiusCard),
    );
    expect(theme.textTheme.bodyLarge!.fontFamily, AppTypography.sans);
    expect(theme.textTheme.displayLarge!.fontFamily, AppTypography.serif);
  });

  test('Neo-Brutalism draws ink outlines and a hard shadow', () {
    final theme = _light('dracula', AppStyle.neoBrutalism);
    final colors = theme.extension<AnchorColors>()!;
    final ink = schemeById('dracula')!.light.foreground;
    expect(colors.appBorder, ink);
    expect(colors.shadowRaised.first.spreadRadius, 2);
    expect(colors.shadowRaised.every((s) => s.color == ink), isTrue);
    expect(colors.shadowRaised.every((s) => s.blurRadius == 0), isTrue);
    expect(
      theme.extension<AnchorStyle>()!.corners(AnchorTokens.radiusCard),
      BorderRadius.circular(6),
    );
    expect(theme.textTheme.bodyLarge!.fontFamily, AppTypography.spaceGrotesk);
    expect(
      theme.extension<NoteTypography>()!.family,
      AppTypography.spaceGrotesk,
    );
  });

  test('Lo-fi has no depth, wobbly corners, handwriting and grey marks', () {
    final theme = _light(anchorSchemeId, AppStyle.lofi);
    final colors = theme.extension<AnchorColors>()!;
    final style = theme.extension<AnchorStyle>()!;
    expect(colors.shadowSm, isEmpty);
    expect(colors.shadowRaised.single.blurRadius, 0);
    expect(style.corners(AnchorTokens.radiusCard), AnchorStyle.wobbly);
    // Small things keep round corners; pills stay pills.
    expect(
      style.corners(AnchorTokens.radiusLg),
      BorderRadius.circular(AnchorTokens.radiusLg),
    );
    expect(
      style.corners(AnchorTokens.radiusPill),
      BorderRadius.circular(AnchorTokens.radiusPill),
    );
    expect(style.pattern, isNotNull);
    expect(colors.highlights.values.map((h) => h.fill).toSet(), hasLength(1));
    expect(theme.textTheme.bodyLarge!.fontFamily, AppTypography.patrickHand);
  });

  test('Skeuomorphism keeps the fonts, softens corners, sets serif titles', () {
    final theme = _light(anchorSchemeId, AppStyle.skeuomorphism);
    final style = theme.extension<AnchorStyle>()!;
    expect(style.corners(AnchorTokens.radiusCard), BorderRadius.circular(10));
    expect(style.pattern, isNotNull);
    expect(theme.textTheme.bodyLarge!.fontFamily, AppTypography.sans);
    final notes = theme.extension<NoteTypography>()!;
    expect(notes.family, AppTypography.sans);
    expect(notes.title.fontFamily, AppTypography.serif);
  });

  test('the style fonts are bundled with their licences', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final (family, file, licence) in [
      (AppTypography.spaceGrotesk, 'SpaceGrotesk-Variable.ttf', 'SpaceGrotesk'),
      (AppTypography.patrickHand, 'PatrickHand-Regular.ttf', 'PatrickHand'),
    ]) {
      expect(pubspec, contains('- family: $family'));
      expect(pubspec, contains('assets/fonts/$file'));
      expect(File('assets/fonts/$file').existsSync(), isTrue);
      expect(File('assets/fonts/OFL-$licence.txt').existsSync(), isTrue);
    }
    expect(pubspec, isNot(contains('google_fonts')));
  });

  test('high contrast darkens text and secondary text on every scheme', () {
    for (final scheme in [anchorSchemeId, ...appSchemes.map((s) => s.id)]) {
      for (final dark in [false, true]) {
        ThemeData theme(bool highContrast) =>
            (dark ? AppTheme.dark : AppTheme.light)(
              DisplayDensity.standard,
              NoteFont.sans,
              NoteTextSize.standard,
              scheme,
              AppStyle.standard,
              null,
              highContrast,
            );
        final plain = theme(false).extension<AnchorColors>()!;
        final high = theme(true).extension<AnchorColors>()!;
        final where = '$scheme ${dark ? 'dark' : 'light'}';
        expect(
          _contrast(high.appText, high.appPage),
          greaterThanOrEqualTo(_contrast(plain.appText, plain.appPage)),
          reason: where,
        );
        expect(
          _contrast(high.appMuted, high.appPage),
          greaterThan(_contrast(plain.appMuted, plain.appPage)),
          reason: where,
        );
        for (final MapEntry(key: name, value: note) in high.notes.entries) {
          expect(
            _contrast(note.muted, note.bg),
            greaterThan(_contrast(plain.notes[name]!.muted, note.bg)),
            reason: '$where $name',
          );
        }
      }
    }
  });

  test('high contrast sets note text heavier', () {
    NoteTypography typography(bool highContrast) =>
        AppTheme.light(
          DisplayDensity.standard,
          NoteFont.sans,
          NoteTextSize.standard,
          anchorSchemeId,
          AppStyle.standard,
          null,
          highContrast,
        ).extension<NoteTypography>()!;
    expect(typography(false).body.fontWeight, FontWeight.w400);
    expect(typography(true).body.fontWeight, FontWeight.w500);
    expect(typography(true).cardBody.fontWeight, FontWeight.w500);
  });

  test('the share sheet keeps the scheme and style', () {
    const context = ShareContext(
      colorScheme: 'nord',
      style: AppStyle.lofi,
      highContrast: false,
    );
    final read = ShareContext.fromJson(context.toJson());
    expect(read.colorScheme, 'nord');
    expect(read.style, AppStyle.lofi);
    expect(read.highContrast, isFalse);
    final unknown = ShareContext.fromJson({'scheme': 'nope', 'style': 1});
    expect(unknown.colorScheme, anchorSchemeId);
    expect(unknown.style, AppStyle.standard);
    expect(unknown.highContrast, isTrue);
  });

  testWidgets('switching scheme and style redraws colours, corners and font', (
    tester,
  ) async {
    await tester.pumpWidget(
      const _Host(scheme: anchorSchemeId, style: AppStyle.standard),
    );
    var group = _groupOf(tester, find.byType(GroupedList));
    expect(group.color, AnchorColors.light.appSurface);
    expect(group.borderRadius, BorderRadius.circular(AnchorTokens.radius2xl));
    expect(_familyOf(tester, 'Row'), AppTypography.sans);
    expect(_familyOf(tester, 'Plain'), AppTypography.sans);

    await tester.pumpWidget(
      const _Host(scheme: 'nord', style: AppStyle.neoBrutalism),
    );
    final nord = schemeById('nord')!.light;
    group = _groupOf(tester, find.byType(GroupedList));
    expect(group.color, nord.card);
    expect(group.borderRadius, BorderRadius.circular(6));
    expect(group.boxShadow!.first.color, nord.foreground);
    expect(_familyOf(tester, 'Row'), AppTypography.spaceGrotesk);
    expect(_familyOf(tester, 'Plain'), AppTypography.spaceGrotesk);
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor ??
          Theme.of(
            tester.element(find.byType(Scaffold)),
          ).scaffoldBackgroundColor,
      nord.background,
    );

    await tester.pumpWidget(const _Host(scheme: 'nord', style: AppStyle.lofi));
    group = _groupOf(tester, find.byType(GroupedList));
    expect(group.color, lofiScheme.light.card);
    expect(group.borderRadius, AnchorStyle.wobbly);
    expect(_familyOf(tester, 'Plain'), AppTypography.patrickHand);

    await tester.pumpWidget(
      const _Host(scheme: anchorSchemeId, style: AppStyle.standard),
    );
    expect(_familyOf(tester, 'Plain'), AppTypography.sans);
    expect(
      tester.element(find.byType(_PlainText)).appStyle.style,
      AppStyle.standard,
    );
  });

  test('OLED is pure black in dark mode, and its cards keep an outline', () {
    final oled = schemeById('oled')!;
    expect(oled.name, 'OLED');
    expect(oled.dark.background, const Color(0xFF000000));
    expect(oled.dark.sidebar, const Color(0xFF000000));
    expect(oled.dark.card, isNot(oled.dark.background));

    final dark = _dark('oled');
    final colors = dark.extension<AnchorColors>()!;
    expect(dark.scaffoldBackgroundColor, const Color(0xFF000000));
    expect(dark.colorScheme.onSurface, const Color(0xFFFFFFFF));
    // Shadows can't show on black: what they lift gets a hairline instead.
    expect(colors.shadowXs.single.color, oled.dark.border);
    expect(colors.shadowXs.single.blurRadius, 0);
    expect(colors.notes['none']!.bg, oled.dark.card);
    // High contrast: white on black, and the muted text well past AA.
    expect(
      _contrast(oled.dark.mutedForeground, oled.dark.background),
      greaterThan(7),
    );

    // Its light side is Anchor's light, and keeps Anchor's soft shadows.
    final light = _light('oled').extension<AnchorColors>()!;
    expect(light.appPage, AnchorColors.light.appPage);
    expect(light.shadowXs, AnchorColors.light.shadowXs);
  });

  testWidgets(
    'on OLED a plain note is a near-black card; coloured notes keep theirs',
    (tester) async {
      final oled = schemeById('oled')!;
      late NoteAppearance plain, red;
      await tester.pumpWidget(
        MaterialApp(
          theme: _dark('oled'),
          home: Builder(
            builder: (context) {
              plain = NoteAppearance.of(context, null);
              red = NoteAppearance.of(context, 'color_red');
              return const SizedBox();
            },
          ),
        ),
      );
      expect(plain.colors.bg, oled.dark.card);
      expect(red.colors.bg, AnchorColors.dark.notes['red']!.bg);
      // Both stand off the black page.
      expect(_contrast(red.colors.bg, oled.dark.background), greaterThan(1.2));
    },
  );

  test("Gruvbox's dark side is true Gruvbox dark", () {
    final dark = schemeById('gruvbox')!.dark;
    expect(dark.background, const Color(0xFF282828)); // bg
    expect(dark.card, const Color(0xFF3C3836)); // bg1
    expect(dark.sidebar, const Color(0xFF1D2021)); // bg0_h
    expect(dark.muted, const Color(0xFF504945)); // bg2
    expect(dark.foreground, const Color(0xFFEBDBB2)); // fg
    expect(dark.mutedForeground, const Color(0xFFBDAE93)); // fg3
    expect(dark.accent, const Color(0xFFFE8019)); // bright orange
    expect(dark.accentInk, const Color(0xFFFABD2F)); // bright yellow
    expect(dark.destructive, const Color(0xFFFB4934)); // bright red
  });

  testWidgets('Lo-fi draws every note plain', (tester) async {
    late NoteAppearance yellow;
    late NoteAppearance plain;
    await tester.pumpWidget(
      MaterialApp(
        theme: _light('nord', AppStyle.lofi),
        home: Builder(
          builder: (context) {
            yellow = NoteAppearance.of(context, 'color_yellow');
            plain = NoteAppearance.of(context, null);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(yellow.palette, 'none');
    expect(yellow.colors.bg, lofiScheme.light.card);
    expect(plain.colors.bg, lofiScheme.light.card);
  });

  group('Settings › Appearance', () {
    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      PackageInfo.setMockInitialValues(
        appName: 'Anchor',
        packageName: 'anchor',
        version: '1.0.0',
        buildNumber: '1',
        buildSignature: '',
      );
    });

    Future<ProviderContainer> pumpSettings(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final container = ProviderContainer(
        overrides: [
          isOnlineProvider.overrideWithValue(true),
          serverUrlProvider.overrideWithValue('https://example.test'),
          authControllerProvider.overrideWith(_SignedOut.new),
          oidcConfigProvider.overrideWith((ref) async => const OidcConfig()),
          serverInfoProvider.overrideWith((ref) async => null),
          syncCompatibilityProvider.overrideWith(
            (ref) async => SyncCompatibility.ok,
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const _SettingsApp(),
        ),
      );
      await tester.pumpAndSettle();
      return container;
    }

    Future<void> choose(WidgetTester tester, String row, String option) async {
      await tester.ensureVisible(find.text(row));
      await tester.tap(find.text(row));
      await tester.pumpAndSettle();
      await tester.tap(find.text(option).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
    }

    testWidgets('picks a colour scheme and a style, and keeps them', (
      tester,
    ) async {
      final container = await pumpSettings(tester);
      final appearance = find.ancestor(
        of: find.text('Color scheme'),
        matching: find.byType(GroupedList),
      );
      expect(
        find.descendant(of: appearance, matching: find.text('Anchor+')),
        findsOneWidget,
      );
      expect(_groupOf(tester, appearance).color, AnchorColors.light.appSurface);

      await choose(tester, 'Color scheme', 'Gruvbox');
      expect(container.read(colorSchemeControllerProvider), 'gruvbox');
      final gruvbox = schemeById('gruvbox')!.light;
      expect(_groupOf(tester, appearance).color, gruvbox.card);
      expect(
        find.descendant(of: appearance, matching: find.text('Gruvbox')),
        findsOneWidget,
      );

      await choose(tester, 'Style', 'Neo-Brutalism');
      expect(container.read(appStyleControllerProvider), AppStyle.neoBrutalism);
      expect(
        _groupOf(tester, appearance).borderRadius,
        BorderRadius.circular(6),
      );
      expect(_familyOf(tester, 'Color scheme'), AppTypography.spaceGrotesk);

      const storage = FlutterSecureStorage();
      expect(await storage.read(key: StorageKeys.colorScheme), 'gruvbox');
      expect(
        await storage.read(key: StorageKeys.appStyle),
        AppStyle.neoBrutalism.id,
      );

      await choose(tester, 'Style', 'Lo-fi');
      expect(
        find.text('Lo-fi draws in pencil grays, whatever the scheme.'),
        findsOneWidget,
      );
      expect(_familyOf(tester, 'Color scheme'), AppTypography.patrickHand);
    });

    testWidgets('high contrast is on until turned off, and stays off', (
      tester,
    ) async {
      final container = await pumpSettings(tester);
      expect(container.read(highContrastControllerProvider), isTrue);
      final before = _textColorOf(tester, 'Color scheme');

      await tester.ensureVisible(find.text('High contrast'));
      await tester.tap(find.text('High contrast'));
      await tester.pumpAndSettle();

      expect(container.read(highContrastControllerProvider), isFalse);
      expect(
        await const FlutterSecureStorage().read(key: StorageKeys.highContrast),
        'false',
      );
      final after = _textColorOf(tester, 'Color scheme');
      expect(
        _contrast(after, AnchorColors.light.appPage),
        lessThan(_contrast(before, AnchorColors.light.appPage)),
      );
    });

    testWidgets('applies, checks, copies and resets a custom theme', (
      tester,
    ) async {
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
      final container = await pumpSettings(tester);
      final appearance = find.ancestor(
        of: find.text('Custom theme'),
        matching: find.byType(GroupedList),
      );
      Future<void> open() async {
        await tester.ensureVisible(find.text('Custom theme'));
        await tester.tap(find.text('Custom theme'));
        await tester.pumpAndSettle();
      }

      Future<void> press(String label) async {
        await tester.pump();
        await tester.ensureVisible(find.text(label).last);
        await tester.tap(find.text(label).last);
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      expect(
        find.descendant(of: appearance, matching: find.text('None')),
        findsOneWidget,
      );
      await open();
      final field = find.byKey(const Key('custom-theme-json'));
      await tester.enterText(field, '{"light": {"bakground": "#000"}}');
      await press('Apply');
      expect(
        find.textContaining('light.bakground: unknown key'),
        findsOneWidget,
      );
      expect(container.read(customThemeControllerProvider), isNull);

      await tester.enterText(
        field,
        '{"name": "Ink", "light": {"background": "#102030"}}',
      );
      await press('Apply');
      expect(find.byKey(const Key('custom-theme-json')), findsNothing);
      expect(container.read(customThemeControllerProvider)?.name, 'Ink');
      expect(
        find.textContaining('Custom theme “Ink” applied', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.descendant(of: appearance, matching: find.text('Ink')),
        findsOneWidget,
      );
      expect(
        Theme.of(tester.element(appearance)).scaffoldBackgroundColor,
        const Color(0xFF102030),
      );
      const storage = FlutterSecureStorage();
      expect(
        await storage.read(key: StorageKeys.customTheme),
        '{"name":"Ink","light":{"background":"#102030"}}',
      );

      await open();
      expect(find.textContaining('"#102030"'), findsOneWidget);
      await press('Copy current theme as JSON');
      expect(find.text('Current theme copied as JSON'), findsOneWidget);
      final copied = parseCustomTheme(clipboard!).theme!;
      expect(copied.name, 'Ink');
      expect(copied.light!['background'], const Color(0xFF102030));
      expect(copied.dark!['background'], AnchorColors.dark.appPage);

      await press('Reset');
      expect(container.read(customThemeControllerProvider), isNull);
      expect(await storage.read(key: StorageKeys.customTheme), isNull);
      expect(
        find.descendant(of: appearance, matching: find.text('None')),
        findsOneWidget,
      );
    });
  });
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}
