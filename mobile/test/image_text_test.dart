import 'dart:io';

import 'package:anchor/core/files/image_text.dart';
import 'package:anchor/core/logging/app_logger.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// ML Kit's answer for blocks of lines, each word 100 × 20 px, a line per
/// 30 px down the picture.
RecognizedText _recognized(List<List<String>> blocks) {
  var y = 0;
  Map<String, Object?> part(
    String text,
    Rect rect, {
    List<Object?> lines = const [],
    List<Object?> elements = const [],
  }) => {
    'text': text,
    'rect': {
      'left': rect.left,
      'top': rect.top,
      'right': rect.right,
      'bottom': rect.bottom,
    },
    'points': <Object?>[],
    'recognizedLanguages': ['en'],
    'confidence': 0.9,
    'angle': 0.0,
    'lines': lines,
    'elements': elements,
    'symbols': <Object?>[],
  };
  Map<String, Object?> line(String text) {
    final words = text.split(' ');
    final top = (y++ * 30).toDouble();
    return part(
      text,
      Rect.fromLTWH(0, top, words.length * 110.0, 20),
      elements: [
        for (final (i, w) in words.indexed)
          part(w, Rect.fromLTWH(i * 110.0, top, 100, 20)),
      ],
    );
  }

  return RecognizedText.fromJson({
    'text': blocks.expand((b) => b).join('\n'),
    'blocks': [
      for (final lines in blocks)
        part(
          lines.join('\n'),
          Rect.zero,
          lines: [for (final l in lines) line(l)],
        ),
    ],
  });
}

List<LogEntry> _logsSince(int before) =>
    AppLogger.instance.snapshot.skip(before).toList();

ImageWord _word(String text, Rect rect, {int line = 0, int block = 0}) =>
    ImageWord(text: text, rect: rect, line: line, block: block);

void main() {
  late Directory dir;
  late String path;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('image_text_test');
    path = '${dir.path}/Screenshot_20261026-153012_Notes.png';
    File(path).writeAsBytesSync(List.filled(2048, 0));
  });

  tearDown(() => dir.deleteSync(recursive: true));

  test('finds each word with its place, and logs what it found', () async {
    final before = AppLogger.instance.snapshot.length;
    final found = await recognizeImageText(
      path,
      reader: (_) async => _recognized([
        ['Shopping list'],
        ['Milk and bread', 'Call the dentist'],
      ]),
    );

    expect(found.words.map((w) => w.text), [
      'Shopping',
      'list',
      'Milk',
      'and',
      'bread',
      'Call',
      'the',
      'dentist',
    ]);
    expect(found.words[3].rect, const Rect.fromLTWH(110, 30, 100, 20));
    expect(found.text, 'Shopping list\n\nMilk and bread\nCall the dentist');

    final logs = _logsSince(before);
    expect(
      logs.first.message,
      contains('Reading Screenshot_20261026-153012_Notes.png (2048 bytes'),
    );
    expect(logs.last.level, LogLevel.info);
    expect(
      logs.last.message,
      contains('2 blocks, 3 lines, 8 words, 46 characters'),
    );
  });

  test('logs why a read failed, then passes the error on', () async {
    final before = AppLogger.instance.snapshot.length;
    final failure = PlatformException(
      code: 'error',
      message: 'Attempt to invoke virtual method on a null object reference',
    );

    await expectLater(
      recognizeImageText(path, reader: (_) async => throw failure),
      throwsA(same(failure)),
    );

    final logged = _logsSince(before).last;
    expect(logged.level, LogLevel.error);
    expect(logged.tag, 'ImageText');
    expect(logged.message, contains('Screenshot_20261026-153012_Notes.png'));
    expect(logged.message, contains('2048 bytes'));
    expect(logged.message, contains('code=error'));
    expect(logged.message, contains('null object reference'));
    expect(logged.error, same(failure));
  });

  test('a selection keeps its lines and paragraphs', () {
    final words = [
      _word('Milk', Rect.zero),
      _word('and', Rect.zero),
      _word('bread', Rect.zero, line: 1),
      _word('Call', Rect.zero, line: 2, block: 1),
    ];

    expect(joinImageWords(words), 'Milk and\nbread\n\nCall');
    expect(joinImageWords(words.skip(1).take(2)), 'and\nbread');
  });

  test('a box takes the words it touches, in reading order', () {
    final words = [
      _word('Milk', const Rect.fromLTWH(0, 0, 100, 20)),
      _word('bread', const Rect.fromLTWH(140, 0, 100, 20)),
      _word('Call', const Rect.fromLTWH(0, 60, 100, 20), line: 1),
    ];

    expect(imageWordsIn(words, const Rect.fromLTRB(50, 10, 60, 70)), [0, 2]);
    expect(imageWordsIn(words, const Rect.fromLTRB(90, -5, 150, 5)), [0, 1]);
    expect(imageWordsIn(words, const Rect.fromLTRB(110, 30, 130, 50)), []);
  });

  group('the word under a finger', () {
    final words = [
      _word('Milk', const Rect.fromLTWH(0, 0, 100, 20)),
      _word('bread', const Rect.fromLTWH(140, 0, 100, 20)),
      _word('Call', const Rect.fromLTWH(0, 60, 100, 20), line: 1),
    ];

    test('is the word it touches', () {
      expect(imageWordAt(words, const Offset(50, 10)), 0);
      expect(imageWordAt(words, const Offset(150, 15)), 1);
      expect(imageWordAt(words, const Offset(10, 70)), 2);
    });

    test('is the nearest word on the line just beside it', () {
      expect(imageWordAt(words, const Offset(115, 10)), 0);
      expect(imageWordAt(words, const Offset(130, 10)), 1);
      expect(imageWordAt(words, const Offset(50, 28)), 0);
    });

    test('is none far from any text', () {
      expect(imageWordAt(words, const Offset(50, 45)), isNull);
      expect(imageWordAt(words, const Offset(400, 10)), isNull);
    });
  });

  // ML Kit creates its components by reflection, so R8 sees their
  // constructors as unused. Without this rule, every read in a release build
  // fails, while debug builds and these tests keep working.
  test('release builds keep the constructors ML Kit creates by reflection', () {
    final rules = File('android/app/proguard-rules.pro').readAsLinesSync();
    expect(
      rules.map((line) => line.trim()),
      contains('-keep class com.google.mlkit.**.*Registrar { <init>(); }'),
    );
  });
}
