import 'package:anchor/core/theme/custom_theme.dart';
import 'package:anchor/features/addons/addons.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> addonJson({
  String id = 'a1',
  bool enabled = true,
  Object? theme,
  List<String>? styles,
}) => {
  'id': id,
  'addonId': 'dev.example.$id',
  'version': '1.0.0',
  'enabled': enabled,
  'manifest': {
    'id': 'dev.example.$id',
    'name': 'Addon $id',
    'version': '1.0.0',
    'anchorApi': 1,
    'description': 'Warm colours',
    'contributes': {'theme': ?theme, 'styles': ?styles},
  },
  'files': const {},
};

void main() {
  group('InstalledAddon', () {
    test('reads an addon as api/addons lists it', () {
      final addon = InstalledAddon.fromJson(
        addonJson(
          theme: {
            'dark': {'accent': '#b58900'},
          },
          styles: ['style.css'],
        ),
      )!;
      expect(addon.name, 'Addon a1');
      expect(addon.description, 'Warm colours');
      expect(addon.enabled, isTrue);
      expect(addon.hasStyles, isTrue);
      expect(addon.theme?.dark?['accent'], const Color(0xFFB58900));
    });

    test("leaves out what doesn't read", () {
      expect(
        InstalledAddon.listFromJson([
          addonJson(),
          {'id': 3},
          'nonsense',
        ]).map((a) => a.id),
        ['a1'],
      );
      expect(InstalledAddon.listFromJson(null), isEmpty);
    });
  });

  group('withAddonThemes', () {
    InstalledAddon addon(
      String id,
      Map<String, String> dark, {
      bool on = true,
    }) => InstalledAddon.fromJson(
      addonJson(id: id, enabled: on, theme: {'dark': dark}),
    )!;

    test('lays the addons on in order, and the custom theme over them', () {
      final own = parseCustomTheme('{"dark": {"card": "#000000"}}').theme;
      final theme = withAddonThemes([
        addon('a', {'accent': '#111111', 'card': '#222222'}),
        addon('b', {'accent': '#333333'}),
      ], own)!;
      expect(theme.dark, {
        'accent': const Color(0xFF333333),
        'card': const Color(0xFF000000),
      });
      expect(theme.light, isNull);
    });

    test('leaves out addons that are off', () {
      final own = parseCustomTheme('{"light": {"card": "#ffffff"}}').theme;
      expect(
        withAddonThemes([
          addon('a', {'accent': '#111111'}, on: false),
        ], own),
        own,
      );
      expect(withAddonThemes(const [], null), isNull);
    });
  });
}
