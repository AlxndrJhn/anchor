import 'package:anchor/core/links/link_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeUrl', () {
    test('adds https to a bare address', () {
      expect(normalizeUrl('example.com'), 'https://example.com');
      expect(
        normalizeUrl(' example.com/path?q=1 '),
        'https://example.com/path?q=1',
      );
      expect(normalizeUrl('localhost:3000'), 'https://localhost:3000');
    });

    test('keeps an address that has its scheme', () {
      for (final url in [
        'https://example.com',
        'HTTP://example.com',
        'mailto:hi@example.com',
        'tel:+15551234',
        'geo:51.5,-0.1',
      ]) {
        expect(normalizeUrl(url), url, reason: url);
      }
    });

    test('leaves text that is not an address as it is, trimmed', () {
      expect(normalizeUrl('  hello  '), 'hello');
      expect(normalizeUrl('   '), '');
    });
  });

  group('isLikelyUrl', () {
    test('accepts addresses with or without a scheme', () {
      for (final url in [
        'example.com',
        'sub.example.co.uk/a?b=1#c',
        'https://example.com',
        'mailto:hi@example.com',
        'tel:5551234',
        'localhost:3000',
        '  example.com  ',
      ]) {
        expect(isLikelyUrl(url), isTrue, reason: url);
      }
    });

    test('rejects words and sentences', () {
      for (final text in ['', '   ', 'hello', 'example', 'two words.com']) {
        expect(isLikelyUrl(text), isFalse, reason: text);
      }
    });

    test('reads numbers as prose, but a full dotted quad as a host', () {
      expect(isLikelyUrl('3.14'), isFalse);
      expect(isLikelyUrl('192.168'), isFalse);
      expect(isLikelyUrl('192.168.1.20'), isTrue);
      expect(normalizeUrl('3.14'), '3.14');
    });
  });

  group('isFullUrl', () {
    test('accepts an address with its scheme or starting with www.', () {
      for (final url in [
        'https://example.com',
        'http://localhost:3000/a',
        'mailto:hi@example.com',
        'www.example.com',
        'WWW.Example.com/path?q=1',
        '  www.example.com  ',
      ]) {
        expect(isFullUrl(url), isTrue, reason: url);
      }
    });

    test('rejects bare names and words', () {
      for (final text in [
        'example.com',
        'www',
        'www.',
        'hello',
        'https://two words',
        '',
      ]) {
        expect(isFullUrl(text), isFalse, reason: text);
      }
    });
  });

  group('linkForTypedAddress', () {
    test('links an address, www. over https, and an email', () {
      expect(linkForTypedAddress('https://example.com'), 'https://example.com');
      expect(linkForTypedAddress('www.example.com'), 'https://www.example.com');
      expect(linkForTypedAddress('hi@example.com'), 'mailto:hi@example.com');
      expect(
        linkForTypedAddress('a.b+c@mail.example.org'),
        'mailto:a.b+c@mail.example.org',
      );
    });

    test('leaves bare names, schemes on their own and other words', () {
      for (final word in [
        'example.com',
        'https://',
        'mailto:',
        'hi@example',
        '@example.com',
        'word',
      ]) {
        expect(linkForTypedAddress(word), isNull, reason: word);
      }
    });
  });
}
