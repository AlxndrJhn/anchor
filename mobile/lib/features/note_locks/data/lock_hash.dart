import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// PBKDF2-HMAC-SHA256 (RFC 8018) of [password] with [salt], [length] bytes.
Uint8List pbkdf2Sha256(
  List<int> password,
  List<int> salt,
  int iterations,
  int length,
) {
  final hmac = Hmac(sha256, password);
  const blockSize = 32;
  final out = Uint8List(length);
  final blocks = (length + blockSize - 1) ~/ blockSize;
  for (var block = 1; block <= blocks; block++) {
    var u = hmac.convert([
      ...salt,
      (block >> 24) & 0xff,
      (block >> 16) & 0xff,
      (block >> 8) & 0xff,
      block & 0xff,
    ]).bytes;
    final t = Uint8List.fromList(u);
    for (var i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < blockSize; j++) {
        t[j] ^= u[j];
      }
    }
    final offset = (block - 1) * blockSize;
    final take = length - offset < blockSize ? length - offset : blockSize;
    out.setRange(offset, offset + take, t);
  }
  return out;
}

/// Whether [secret] is the PIN or pattern behind [stored], a server hash
/// "pbkdf2-sha256$iterations$salt$hash" (salt and hash in base64).
/// Anything else never matches.
bool lockSecretMatches(String secret, String stored) {
  final parts = stored.split(r'$');
  if (parts.length != 4 || parts[0] != 'pbkdf2-sha256') return false;
  final iterations = int.tryParse(parts[1]);
  if (iterations == null || iterations < 1) return false;
  final List<int> salt;
  final List<int> expected;
  try {
    salt = base64.decode(parts[2]);
    expected = base64.decode(parts[3]);
  } on FormatException {
    return false;
  }
  if (expected.isEmpty) return false;
  final actual = pbkdf2Sha256(
    utf8.encode(secret),
    salt,
    iterations,
    expected.length,
  );
  // Same time whichever byte differs.
  var diff = 0;
  for (var i = 0; i < expected.length; i++) {
    diff |= actual[i] ^ expected[i];
  }
  return diff == 0;
}

/// [lockSecretMatches] off the UI thread: thousands of rounds take a
/// noticeable moment on a phone.
Future<bool> verifyLockSecret(String secret, String stored) =>
    Isolate.run(() => lockSecretMatches(secret, stored));

/// A PIN is 4 to 12 digits.
bool isValidPin(String pin) => RegExp(r'^\d{4,12}$').hasMatch(pin);

/// A pattern joins 4 to 9 of the dots 0-8, none twice.
bool isValidPattern(String pattern) =>
    RegExp(r'^[0-8]{4,9}$').hasMatch(pattern) &&
    pattern.split('').toSet().length == pattern.length;
