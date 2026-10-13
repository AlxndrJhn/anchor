import 'package:anchor/core/text/name_order.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // The order the web's collator gives for these names.
  const webOrder = [
    '_misc',
    '-dash',
    '~inbox',
    '10',
    '1st',
    '2',
    'aero',
    'Ærø',
    'apple',
    'Bugs',
    'ecole',
    'Ecole',
    'école',
    'Ethics',
    'lodz',
    'łódź',
    'strasse',
    'straße',
    'to do',
    'to-do',
    'todo',
    'work',
    'Work',
    'zoo',
    'Ωmega',
    'москва',
    '日記',
  ];

  test('names sort the way the web sorts them', () {
    expect(sortedByName(webOrder.reversed, (name) => name), webOrder);
  });

  test('every pair compares the same either way round', () {
    for (var i = 0; i < webOrder.length; i++) {
      for (var j = i + 1; j < webOrder.length; j++) {
        expect(compareNames(webOrder[i], webOrder[j]), isNegative);
        expect(compareNames(webOrder[j], webOrder[i]), isPositive);
      }
    }
  });

  test('an accent typed as its own mark sorts with the letter', () {
    expect(compareNames('école', 'ecolf'), isNegative);
    expect(compareNames('école', 'ecole'), isNonZero);
  });

  test('a name equals only itself', () {
    expect(compareNames('Work', 'Work'), 0);
  });
}
