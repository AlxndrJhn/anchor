import 'package:anchor/features/tags/domain/tag.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a note shows its tags by name, ignoring case', () {
    const travel = Tag(id: 'b', name: 'travel');
    const family = Tag(id: 'c', name: 'Family');
    const work = Tag(id: 'a', name: 'work');
    final byId = {
      for (final tag in [travel, family, work]) tag.id: tag,
    };

    expect(tagsByName(['a', 'b', 'c', 'gone'], byId), [family, travel, work]);
  });
}
