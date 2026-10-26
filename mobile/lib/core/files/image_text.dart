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

/// A word found in a picture, and where it is, in the picture's pixels.
class ImageWord {
  const ImageWord({
    required this.text,
    required this.rect,
    required this.line,
    required this.block,
  });

  final String text;
  final Rect rect;

  /// The line and paragraph it belongs to, counted through the picture.
  final int line;
  final int block;
}

/// The words found in a picture, in reading order.
class ImageText {
  const ImageText(this.words);

  final List<ImageWord> words;

  bool get isEmpty => words.isEmpty;

  /// All the text: a line per line, paragraphs apart.
  String get text => joinImageWords(words);
}

/// Puts words back together as text: spaces within a line, a line break
/// between lines and, with [paragraphs], an empty line between paragraphs.
String joinImageWords(Iterable<ImageWord> words, {bool paragraphs = true}) {
  final out = StringBuffer();
  ImageWord? previous;
  for (final word in words) {
    if (previous != null) {
      out.write(
        word.block != previous.block && paragraphs
            ? '\n\n'
            : word.line != previous.line || word.block != previous.block
            ? '\n'
            : ' ',
      );
    }
    out.write(word.text);
    previous = word;
  }
  return out.toString().trim();
}

/// The index of the word at [point] (in the picture's pixels), or null.
///
/// A finger is wider than the gap between words, so a point just beside a
/// word, up to [slop] away or twice the word's height along its line, counts
/// as the nearest word.
int? imageWordAt(List<ImageWord> words, Offset point, {double slop = 12}) {
  int? nearest;
  var nearestDistance = double.infinity;
  for (final (i, word) in words.indexed) {
    final rect = word.rect;
    if (point.dy < rect.top - slop || point.dy > rect.bottom + slop) continue;
    final dx = point.dx < rect.left
        ? rect.left - point.dx
        : point.dx > rect.right
        ? point.dx - rect.right
        : 0.0;
    if (dx > rect.height * 2 + slop) continue;
    // Ties (a point between two lines) go to the line nearer its middle.
    final distance = dx + (point.dy - rect.center.dy).abs() / 1000;
    if (distance < nearestDistance) {
      nearest = i;
      nearestDistance = distance;
    }
  }
  return nearest;
}

/// The indices of the words a box (in the picture's pixels) touches, in
/// reading order.
List<int> imageWordsIn(List<ImageWord> words, Rect box) => [
  for (final (i, word) in words.indexed)
    if (word.rect.overlaps(box)) i,
];

/// "Grab image text": finds the words in a picture on the phone itself, with
/// ML Kit's Latin-script model.
///
/// Each read is logged (the picture, how long it took, what was found, or
/// why it failed), so a failure on someone's phone shows in their logs.
Future<ImageText> recognizeImageText(String path, {TextReader? reader}) async {
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
    final words = <ImageWord>[];
    var line = 0;
    for (final (block, textBlock) in result.blocks.indexed) {
      for (final textLine in textBlock.lines) {
        if (textLine.text.trim().isEmpty) continue;
        // Each word on its own; a line ML Kit didn't split is one word.
        final parts = textLine.elements.isEmpty
            ? [(textLine.text, textLine.boundingBox)]
            : [for (final e in textLine.elements) (e.text, e.boundingBox)];
        for (final (text, rect) in parts) {
          if (text.trim().isEmpty) continue;
          words.add(
            ImageWord(text: text, rect: rect, line: line, block: block),
          );
        }
        line++;
      }
    }
    final found = ImageText(words);
    AppLogger.instance.info(
      _logTag,
      'Read ${p.basename(path)} in ${watch.elapsedMilliseconds} ms: '
      '${result.blocks.length} blocks, $line lines, ${words.length} words, '
      '${found.text.length} characters',
    );
    return found;
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
