/// Android's clipboard goes through a Binder transaction capped near 1 MB,
/// and text travels as UTF-16, so a full log dump can be too big to copy.
const int maxClipboardLogChars = 200000;

/// The newest part of [dump] that fits on the clipboard, cut at a line
/// boundary, with a note at the top when older lines were left out.
String clipboardSafeLog(String dump, {int maxChars = maxClipboardLogChars}) {
  if (dump.length <= maxChars) return dump;
  var start = dump.length - maxChars;
  final nextLine = dump.indexOf('\n', start);
  if (nextLine != -1 && nextLine + 1 < dump.length) start = nextLine + 1;
  return '[Older log lines left out to fit the clipboard. '
      'Use "Save to file" for the full log.]\n${dump.substring(start)}';
}
