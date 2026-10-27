import 'dart:convert';

import 'package:anchor/features/note_locks/data/lock_hash.dart';
import 'package:flutter_test/flutter_test.dart';

String _hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

void main() {
  group('PBKDF2-HMAC-SHA256', () {
    // Vectors computed with Python's hashlib.pbkdf2_hmac.
    test('matches known vectors', () {
      expect(
        base64.encode(
          pbkdf2Sha256(utf8.encode('password'), utf8.encode('salt'), 1, 32),
        ),
        'Eg+2z/z4syxD5yJSVsT4N6hlSMkszDVICAWYfLcL4Xs=',
      );
      expect(
        _hex(
          pbkdf2Sha256(utf8.encode('password'), utf8.encode('salt'), 4096, 32),
        ),
        'c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a',
      );
      // Longer than one block.
      expect(
        _hex(
          pbkdf2Sha256(
            utf8.encode('passwordPASSWORDpassword'),
            utf8.encode('saltSALTsaltSALTsaltSALTsaltSALTsalt'),
            4096,
            40,
          ),
        ),
        '348c89dbcbd32b2f32d814b8116e84cf2b17347ebc1800181c4e2a1fb8dd53e1'
        'c635518c7dac47e9',
      );
    });

    // As the server stores it; the hash from Node's crypto.pbkdf2Sync.
    const stored =
        r'pbkdf2-sha256$20000$c2FsdHNhbHRzYWx0c2FsdA==$'
        '+JUsauocf0Up/qTK9plPxss0wbpw9IuO3T6+eGhr1mQ=';

    test('checks a PIN against the server hash', () async {
      expect(lockSecretMatches('1234', stored), isTrue);
      expect(lockSecretMatches('1235', stored), isFalse);
      expect(await verifyLockSecret('1234', stored), isTrue);
    });

    test('never matches a hash it doesn’t understand', () {
      expect(lockSecretMatches('1234', ''), isFalse);
      expect(lockSecretMatches('1234', r'bcrypt$1$a$b'), isFalse);
      expect(lockSecretMatches('1234', r'pbkdf2-sha256$x$a$b'), isFalse);
      expect(lockSecretMatches('1234', r'pbkdf2-sha256$1$%%$b'), isFalse);
    });
  });

  test('PIN and pattern shapes follow the server', () {
    expect(isValidPin('1234'), isTrue);
    expect(isValidPin('123'), isFalse);
    expect(isValidPin('1234567890123'), isFalse);
    expect(isValidPin('12a4'), isFalse);
    expect(isValidPattern('03678'), isTrue);
    expect(isValidPattern('012'), isFalse);
    expect(isValidPattern('0120'), isFalse);
    expect(isValidPattern('0129'), isFalse);
  });
}
