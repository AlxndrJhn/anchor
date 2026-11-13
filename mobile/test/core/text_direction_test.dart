import 'package:anchor/core/text/text_direction.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a line reads in the direction of its first letter', () {
    expect(firstStrongDirection('שלום, עולם!'), TextDirection.rtl);
    expect(firstStrongDirection('مرحبا بالعالم'), TextDirection.rtl);
    expect(firstStrongDirection('Hello, שלום'), TextDirection.ltr);
    // Numbers and punctuation before the first letter don't count.
    expect(firstStrongDirection('12. חלב'), TextDirection.rtl);
    expect(firstStrongDirection('- (Milk)'), TextDirection.ltr);
    expect(firstStrongDirection('Ünïcode'), TextDirection.ltr);
    expect(firstStrongDirection(''), isNull);
    expect(firstStrongDirection('123 !?'), isNull);
  });
}
