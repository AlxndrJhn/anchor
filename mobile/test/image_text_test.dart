import 'dart:io';

import 'package:anchor/core/files/image_text.dart';
import 'package:anchor/core/logging/app_logger.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

Map<String, Object?> _part(String text, [List<Object?> children = const []]) =>
    {
      'text': text,
      'rect': {'left': 0, 'top': 0, 'right': 10, 'bottom': 10},
      'points': <Object?>[],
      'recognizedLanguages': ['en'],
      'confidence': 0.9,
      'angle': 0.0,
      'lines': children,
      'elements': <Object?>[],
    };

RecognizedText _recognized(List<List<String>> blocks) =>
    RecognizedText.fromJson({
      'text': blocks.expand((b) => b).join('\n'),
      'blocks': [
        for (final lines in blocks)
          _part(lines.join('\n'), [for (final line in lines) _part(line)]),
      ],
    });

List<LogEntry> _logsSince(int before) =>
    AppLogger.instance.snapshot.skip(before).toList();

void main() {
  late Directory dir;
  late String path;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('image_text_test');
    path = '${dir.path}/Screenshot_20261026-153012_Notes.png';
    File(path).writeAsBytesSync(List.filled(2048, 0));
  });

  tearDown(() => dir.deleteSync(recursive: true));

  test('joins lines and blocks, and logs what it found', () async {
    final before = AppLogger.instance.snapshot.length;
    final text = await readImageText(
      path,
      reader: (_) async => _recognized([
        ['Shopping list'],
        ['Milk and bread', 'Call the dentist'],
      ]),
    );

    expect(text, 'Shopping list\n\nMilk and bread\nCall the dentist');
    final logs = _logsSince(before);
    expect(
      logs.first.message,
      contains('Reading Screenshot_20261026-153012_Notes.png (2048 bytes'),
    );
    expect(logs.last.level, LogLevel.info);
    expect(logs.last.message, contains('2 blocks, 3 lines, 46 characters'));
  });

  test('logs why a read failed, then passes the error on', () async {
    final before = AppLogger.instance.snapshot.length;
    final failure = PlatformException(
      code: 'error',
      message: 'Attempt to invoke virtual method on a null object reference',
    );

    await expectLater(
      readImageText(path, reader: (_) async => throw failure),
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
