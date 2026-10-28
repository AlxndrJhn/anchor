import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:flutter_quill/flutter_quill.dart';

/// Typed in a note and followed by a space or Enter, it becomes today's date.
const dateCommand = '/date';

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// 1st, 2nd, 3rd, 4th … 11th, 12th, 13th … 21st.
String ordinal(int n) {
  final tens = n % 100;
  if (tens >= 11 && tens <= 13) return '${n}th';
  return '$n${const {1: 'st', 2: 'nd', 3: 'rd'}[n % 10] ?? 'th'}';
}

/// The date as on this device: "Oct 28th 2026".
String formatLongDate(DateTime date) =>
    '${_months[date.month - 1]} ${ordinal(date.day)} ${date.year}';

final _space = RegExp(r'\s');

/// Where a `/date` starts that [change] has just finished with a space or
/// Enter, in [document] after the change; null if it didn't. The `/` has
/// to start the line or follow a space, so a path like `a/date ` stays.
int? finishedDateCommandAt(Document document, Delta change) {
  var position = 0;
  int? end;
  for (final op in change.toList()) {
    if (op.isDelete) continue;
    position += op.length!;
    if (op.isInsert && op.data is String) end = position;
  }
  if (end == null) return null;
  final start = end - dateCommand.length - 1;
  if (start < 0) return null;
  final typed = document.getPlainText(start, dateCommand.length + 1);
  if (typed.length != dateCommand.length + 1) return null;
  if (!_space.hasMatch(typed[dateCommand.length])) return null;
  if (typed.substring(0, dateCommand.length).toLowerCase() != dateCommand) {
    return null;
  }
  if (start > 0 && !_space.hasMatch(document.getPlainText(start - 1, 1))) {
    return null;
  }
  return start;
}
