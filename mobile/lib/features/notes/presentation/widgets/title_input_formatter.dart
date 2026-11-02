import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';

import '../../../../core/text/composed_text.dart';

/// A typed line break calls [onEnter]; pasted line breaks become one space,
/// and accents typed or pasted apart join their letters.
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
    if (added == '\n' && after.length == before.length + 1) {
      // The field is still taking this edit.
      scheduleMicrotask(onEnter);
      return TextEditingValue(
        text: before,
        selection: TextSelection.collapsed(offset: start),
      );
    }
    final composed = composedInsert(after.substring(0, start), added);
    final from = start - (composed?.joined ?? 0);
    final joined = (composed?.text ?? added).replaceAll(_lineBreak, ' ');
    if (from == start && joined == added) return newValue;
    final addedEnd = after.length - end;
    int mapOffset(int offset) => offset <= from
        ? offset
        : offset >= addedEnd
        ? offset - (addedEnd - from) + joined.length
        : from + joined.length;
    return TextEditingValue(
      text: after.replaceRange(from, addedEnd, joined),
      selection: newValue.selection.copyWith(
        baseOffset: mapOffset(newValue.selection.baseOffset),
        extentOffset: mapOffset(newValue.selection.extentOffset),
      ),
    );
  }
}
