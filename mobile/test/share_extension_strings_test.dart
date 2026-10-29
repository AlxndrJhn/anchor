import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/share_extension_strings.dart';

void main() {
  test('the share extension has the app’s current strings', () {
    final expected = shareExtensionStrings(readArbs(Directory('lib/l10n')));
    expect(
      File(shareExtensionStringsPath).readAsStringSync(),
      expected,
      reason: 'Run dart run tool/share_extension_strings.dart',
    );
  });

  test('plurals become String Catalog variations', () {
    final catalog =
        jsonDecode(
              shareExtensionStrings({
                'en': {
                  for (final key in shareExtensionKeys) key: key,
                  'shareTooBig':
                      '{count, plural, =1{1 file is too big.} other{{count} '
                      'files are too big.}}',
                  'shareTag': 'Tag {name}',
                },
              }),
            )
            as Map<String, Object?>;
    final strings = catalog['strings']! as Map<String, Object?>;
    expect((strings['shareTooBig']! as Map)['localizations'], {
      'en': {
        'variations': {
          'plural': {
            'one': {
              'stringUnit': {
                'state': 'translated',
                'value': '1 file is too big.',
              },
            },
            'other': {
              'stringUnit': {
                'state': 'translated',
                'value': '%lld files are too big.',
              },
            },
          },
        },
      },
    });
    expect(((strings['shareTag']! as Map)['localizations'] as Map)['en'], {
      'stringUnit': {'state': 'translated', 'value': 'Tag %@'},
    });
  });
}
