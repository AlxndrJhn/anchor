import 'dart:io';

import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path/path.dart' as p;

import '../logging/app_logger.dart';

/// Reads the text in the picture at a path; ML Kit's on the phone.
typedef TextReader = Future<RecognizedText> Function(String path);

Future<RecognizedText> _mlKitReader(String path) async {
  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    return await recognizer.processImage(InputImage.fromFilePath(path));
  } finally {
    await recognizer.close();
  }
}

const _logTag = 'ImageText';

/// "Grab image text": reads the text in a picture on the phone itself, with
/// ML Kit's Latin-script model. Returns the text a line per line found, or
/// an empty string when there is none.
///
/// Each read is logged (the picture, how long it took, what was found, or
/// why it failed), so a failure on someone's phone shows in their logs.
Future<String> readImageText(String path, {TextReader? reader}) async {
  final file = File(path);
  final size = file.existsSync() ? '${file.lengthSync()} bytes' : 'missing';
  AppLogger.instance.debug(
    _logTag,
    'Reading ${p.basename(path)} ($size, ${Platform.operatingSystem} '
    '${Platform.operatingSystemVersion})',
  );
  final watch = Stopwatch()..start();
  try {
    final result = await (reader ?? _mlKitReader)(path);
    final text = result.blocks
        .map((block) => block.lines.map((line) => line.text).join('\n'))
        .where((text) => text.trim().isNotEmpty)
        .join('\n\n')
        .trim();
    AppLogger.instance.info(
      _logTag,
      'Read ${p.basename(path)} in ${watch.elapsedMilliseconds} ms: '
      '${result.blocks.length} blocks, '
      '${result.blocks.fold(0, (n, b) => n + b.lines.length)} lines, '
      '${text.length} characters',
    );
    return text;
  } catch (e, stack) {
    final detail = e is PlatformException
        ? 'code=${e.code}, message=${e.message}, details=${e.details}'
        : '$e';
    AppLogger.instance.error(
      _logTag,
      'Reading ${p.basename(path)} failed after '
      '${watch.elapsedMilliseconds} ms ($size): $detail',
      error: e,
      stackTrace: stack,
    );
    rethrow;
  }
}
