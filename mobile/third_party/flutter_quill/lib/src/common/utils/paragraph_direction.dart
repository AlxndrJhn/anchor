// Anchor+: not in upstream flutter_quill.
import 'dart:ui' show TextDirection;

/// The direction of a paragraph from its first strong character, like
/// dir="auto" on the web: right-to-left for Hebrew, Arabic and the other
/// right-to-left scripts, left-to-right for Latin, Greek, Cyrillic, CJK and
/// the other letters; null when it has none, such as digits, punctuation or
/// emoji only.
///
/// The character classes follow Unicode's bidi classes closely enough for
/// text people write, without its tables: combining marks of a script count
/// as that script.
TextDirection? paragraphDirection(String text) {
  for (final c in text.runes) {
    if (_isRtl(c)) return TextDirection.rtl;
    if (_isLtr(c)) return TextDirection.ltr;
  }
  return null;
}

bool _isRtl(int c) =>
    (c >= 0x0590 && c <= 0x08FF && !_isArabicDigit(c)) ||
    (c >= 0xFB1D && c <= 0xFDFF) ||
    (c >= 0xFE70 && c <= 0xFEFE) ||
    (c >= 0x10800 && c <= 0x10FFF) ||
    (c >= 0x1E800 && c <= 0x1EFFF);

// Arabic-Indic digits and separators are weak, like 0-9.
bool _isArabicDigit(int c) =>
    (c >= 0x0660 && c <= 0x066C) || (c >= 0x06F0 && c <= 0x06F9);

bool _isLtr(int c) =>
    (c >= 0x41 && c <= 0x5A) ||
    (c >= 0x61 && c <= 0x7A) ||
    c == 0xAA ||
    c == 0xB5 ||
    c == 0xBA ||
    (c >= 0xC0 && c <= 0x02B8 && c != 0xD7 && c != 0xF7) ||
    (c >= 0x0370 && c <= 0x058F) ||
    (c >= 0x0900 && c <= 0x1FFF) ||
    (c >= 0x2C00 && c <= 0x2DFF) ||
    (c >= 0x3040 && c <= 0xD7FF) ||
    (c >= 0xF900 && c <= 0xFB1C) ||
    (c >= 0xFF21 && c <= 0xFF3A) ||
    (c >= 0xFF41 && c <= 0xFF5A) ||
    (c >= 0xFF66 && c <= 0xFFDC) ||
    (c >= 0x10000 && c <= 0x107FF) ||
    (c >= 0x20000 && c <= 0x3FFFF);
