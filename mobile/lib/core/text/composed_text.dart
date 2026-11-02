import 'package:unorm_dart/unorm_dart.dart' as unorm;

/// [text] with each accent joined into its letter (Unicode NFC), as typing
/// stores it. macOS, other apps' shares and older Vietnamese keyboards send
/// "ệ" as e plus two accents, which a font without "ệ" draws apart; joined,
/// the whole letter falls back to Noto Sans.
///
/// Only text with such an accent is changed, so other letters NFC would
/// swap (CJK compatibility ideographs) stay as they came.
String composedText(String text) =>
    _hasJoiningMark(text) ? unorm.nfc(text) : text;

/// [data] going in after [before] with its accents joined, also into the
/// letter it starts on, when it starts with an accent (a keyboard that types
/// the accent after the letter); [joined] counts the letters of [before]
/// taken in. Null when nothing joins.
({int joined, String text})? composedInsert(String before, String data) {
  if (!_hasJoiningMark(data)) return null;
  var joined = 0;
  if (_isJoiningMark(data.codeUnitAt(0))) {
    var at = before.length;
    while (at > 0 && _isJoiningMark(before.codeUnitAt(at - 1))) {
      at--;
    }
    if (at > 0 && !_isBoundary(before.codeUnitAt(at - 1))) {
      joined = before.length - at + 1;
    }
  }
  final original = before.substring(before.length - joined) + data;
  final text = unorm.nfc(original);
  return text == original ? null : (joined: joined, text: text);
}

bool _hasJoiningMark(String text) {
  for (var i = 0; i < text.length; i++) {
    if (_isJoiningMark(text.codeUnitAt(i))) return true;
  }
  return false;
}

/// Accents NFC can join into the letter before them: Latin, Greek and
/// Cyrillic accents, Hangul vowels and final consonants, kana voicing marks.
bool _isJoiningMark(int unit) =>
    (unit >= 0x0300 && unit <= 0x036F) ||
    (unit >= 0x1AB0 && unit <= 0x1AFF) ||
    (unit >= 0x1DC0 && unit <= 0x1DFF) ||
    (unit >= 0x20D0 && unit <= 0x20FF) ||
    (unit >= 0xFE20 && unit <= 0xFE2F) ||
    (unit >= 0x1160 && unit <= 0x11FF) ||
    unit == 0x3099 ||
    unit == 0x309A;

/// A line break, a picture in the text (Quill's object replacement), or half
/// of an emoji: none takes an accent in.
bool _isBoundary(int unit) =>
    unit == 0x0A || unit == 0xFFFC || (unit >= 0xD800 && unit <= 0xDFFF);
