import 'package:anchor/core/text/composed_text.dart';
import 'package:anchor/features/notes/presentation/widgets/title_input_formatter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// "Việt" with ệ as e, dot below, circumflex: as macOS or a "tổ hợp"
// keyboard sends it.
const _apart = 'Vie\u0323\u0302t';
const _joined = 'Vi\u1EC7t';

void main() {
  group('composedText', () {
    test('joins accents into their letters', () {
      expect(composedText(_apart), _joined);
      expect(composedText('Cafe\u0301'), 'Café');
      // Hangul from macOS file names, kana with a separate voicing mark.
      expect(composedText('\u1112\u1161\u11AB'), '\uD55C');
      expect(composedText('\u304B\u3099'), '\u304C');
    });

    test('leaves text without separate accents as it is', () {
      const text = 'Plain, Việt, 中文 and 🍞';
      expect(identical(composedText(text), text), isTrue);
      // NFC would swap this compatibility ideograph for 豈.
      expect(composedText('\uF900'), '\uF900');
    });

    test('keeps an accent no letter takes in', () {
      expect(composedText('x\u0302'), 'x\u0302');
    });
  });

  group('composedInsert', () {
    test('joins pasted text on its own', () {
      expect(composedInsert('Hello ', _apart), (joined: 0, text: _joined));
    });

    test('takes in the letter before an accent typed after it', () {
      expect(composedInsert('Vie', '\u0302'), (joined: 1, text: '\u00EA'));
      expect(composedInsert('Vie\u0323', '\u0302'), (
        joined: 2,
        text: '\u1EC7',
      ));
    });

    test('nothing joins across a line break, a picture or an emoji', () {
      expect(composedInsert('a\n', '\u0301'), isNull);
      expect(composedInsert('a\uFFFC', '\u0301'), isNull);
      expect(composedInsert('\u{1F35E}', '\u0301'), isNull);
    });

    test('null for text already joined', () {
      expect(composedInsert('', _joined), isNull);
      expect(composedInsert('', 'plain'), isNull);
    });
  });

  group('TitleInputFormatter', () {
    final formatter = TitleInputFormatter(onEnter: () {});

    TextEditingValue type(String before, String after, int caret) =>
        formatter.formatEditUpdate(
          TextEditingValue(
            text: before,
            selection: TextSelection.collapsed(offset: before.length),
          ),
          TextEditingValue(
            text: after,
            selection: TextSelection.collapsed(offset: caret),
          ),
        );

    test('a pasted title has its accents joined, the caret after it', () {
      final value = type('Trip: ', 'Trip: $_apart', 6 + _apart.length);
      expect(value.text, 'Trip: $_joined');
      expect(value.selection, const TextSelection.collapsed(offset: 10));
    });

    test('an accent typed after its letter joins it', () {
      final value = type('Vie', 'Vie\u0302', 4);
      expect(value.text, 'Vi\u00EA');
      expect(value.selection, const TextSelection.collapsed(offset: 3));
    });

    test('pasted line breaks still become a space', () {
      final value = type('', 'Cafe\u0301\nmenu', 10);
      expect(value.text, 'Café menu');
      expect(value.selection, const TextSelection.collapsed(offset: 9));
    });
  });
}
