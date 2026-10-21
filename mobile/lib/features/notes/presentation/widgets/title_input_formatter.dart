import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';

/// A typed line break calls [onEnter]; pasted line breaks become one space.
class TitleInputFormatter extends TextInputFormatter {
  TitleInputFormatter({required this.onEnter});

  final VoidCallback onEnter;

  static final _lineBreak = RegExp(r'\s*[\r\n]\s*');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final before = oldValue.text;
    final after = newValue.text;
    final shorter = math.min(before.length, after.length);
    var start = 0;
    while (start < shorter &&
        before.codeUnitAt(start) == after.codeUnitAt(start)) {
      start++;
    }
    var end = 0;
    while (end < shorter - start &&
        before.codeUnitAt(before.length - 1 - end) ==
            after.codeUnitAt(after.length - 1 - end)) {
      end++;
    }
    final added = after.substring(start, after.length - end);
    if (!added.contains('\n') && !added.contains('\r')) return newValue;
    if (added == '\n' && after.length == before.length + 1) {
      // The field is still taking this edit.
      scheduleMicrotask(onEnter);
      return TextEditingValue(
        text: before,
        selection: TextSelection.collapsed(offset: start),
      );
    }
    final joined = added.replaceAll(_lineBreak, ' ');
    final addedEnd = after.length - end;
    int mapOffset(int offset) => offset <= start
        ? offset
        : offset >= addedEnd
        ? offset - added.length + joined.length
        : start + joined.length;
    return TextEditingValue(
      text: after.replaceRange(start, addedEnd, joined),
      selection: newValue.selection.copyWith(
        baseOffset: mapOffset(newValue.selection.baseOffset),
        extentOffset: mapOffset(newValue.selection.extentOffset),
      ),
    );
  }
}
