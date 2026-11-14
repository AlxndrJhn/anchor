import 'package:anchor/features/picture_search/picture_search.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a detected tag reads in the language the server picked', () {
    final label = PictureLabel.fromJson({
      'en': 'cat',
      'de': 'Katze',
      'text': 'chat',
      'score': 0.12,
    });

    expect(label.textFor('fr'), 'chat');
    expect(label.textFor('de'), 'chat');
    expect(label.score, 0.12);
  });

  test('from an older server, German on a German phone, else English', () {
    final label = PictureLabel.fromJson({'en': 'cat', 'de': 'Katze'});

    expect(label.textFor('de'), 'Katze');
    expect(label.textFor('en'), 'cat');
    expect(label.textFor('fr'), 'cat');
  });
}
