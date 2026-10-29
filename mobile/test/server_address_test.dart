import 'package:anchor/core/network/server_address.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('hostOf', () {
    test('keeps an unusual port', () {
      expect(
        hostOf('https://notes.example.com:8443'),
        'notes.example.com:8443',
      );
      expect(hostOf('http://192.168.1.4:3001'), '192.168.1.4:3001');
    });

    test('leaves out the usual ports and the scheme', () {
      expect(hostOf('https://notes.example.com'), 'notes.example.com');
      expect(hostOf('https://notes.example.com:443'), 'notes.example.com');
      expect(hostOf('http://notes.example.com:80'), 'notes.example.com');
    });
  });

  group('normalizeServerUrl', () {
    test('adds https:// and drops slashes at the end', () {
      expect(
        normalizeServerUrl('  notes.example.com// '),
        'https://notes.example.com',
      );
    });

    test('keeps a plain http:// address and its port', () {
      expect(
        normalizeServerUrl('http://192.168.1.4:3001/'),
        'http://192.168.1.4:3001',
      );
    });

    test('turns down what isn’t a web address', () {
      expect(normalizeServerUrl(''), isNull);
      expect(normalizeServerUrl('   '), isNull);
      expect(normalizeServerUrl('not an address'), isNull);
      expect(normalizeServerUrl('notes_example com'), isNull);
    });
  });
}
