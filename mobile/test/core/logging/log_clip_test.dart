import 'package:anchor/core/logging/log_clip.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps a small log as is', () {
    expect(clipboardSafeLog('a\nb\n', maxChars: 10), 'a\nb\n');
  });

  test('keeps the newest whole lines of a big log', () {
    final dump = List.generate(100, (i) => 'line $i').join('\n');
    final clip = clipboardSafeLog(dump, maxChars: 40);
    expect(clip, startsWith('[Older log lines left out'));
    final kept = clip.split('\n').skip(1).toList();
    expect(kept.last, 'line 99');
    expect(kept.every((l) => l.startsWith('line ')), isTrue);
    expect(kept.join('\n').length, lessThanOrEqualTo(40));
  });
}
