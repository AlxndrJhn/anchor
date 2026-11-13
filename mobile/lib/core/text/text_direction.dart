import 'package:flutter/widgets.dart';

final _rtl = RegExp(
  // Hebrew, Arabic, Syriac, Thaana, NKo, Samaritan, Mandaic and their
  // presentation forms.
  '[֐-ࣿיִ-﷿ﹰ-﻿]|'
  '[\u{10800}-\u{10FFF}\u{1E800}-\u{1EFFF}]',
  unicode: true,
);
final _letter = RegExp(r'\p{L}', unicode: true);

/// The direction [text] reads in, from its first letter, like `dir="auto"`
/// on the web; null when it has no letters, such as an empty line or "123".
TextDirection? firstStrongDirection(String text) {
  for (final char in text.runes) {
    final s = String.fromCharCode(char);
    if (_rtl.hasMatch(s)) return TextDirection.rtl;
    if (_letter.hasMatch(s)) return TextDirection.ltr;
  }
  return null;
}

/// Lays [child] out in [text]'s own direction, so a Hebrew or Arabic line
/// starts at the right in a left to right app. The child fills the width,
/// so it can sit against the right edge.
Widget inTextDirection(BuildContext context, String text, Widget child) {
  final direction = firstStrongDirection(text);
  if (direction == null || direction == Directionality.of(context)) {
    return child;
  }
  return Directionality(
    textDirection: direction,
    child: Align(
      alignment: AlignmentDirectional.centerStart,
      heightFactor: 1,
      child: child,
    ),
  );
}
