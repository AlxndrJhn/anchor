import 'package:anchor/features/picture_search/picture_search.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a detected tag reads in German on a German phone, else English', () {
    final label = PictureLabel.fromJson({
      'en': 'cat',
      'de': 'Katze',
      'score': 0.12,
    });

    expect(label.textFor('de'), 'Katze');
    expect(label.textFor('en'), 'cat');
    expect(label.textFor('fr'), 'cat');
    expect(label.score, 0.12);
  });
}
