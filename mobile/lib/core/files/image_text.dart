import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Whether "Grab image text" can run here: ML Kit reads on the phone, and
/// the fork ships it on Android.
bool get canReadImageText => defaultTargetPlatform == TargetPlatform.android;

/// Reads the text in the picture at a path.
typedef ImageTextReader = Future<String> Function(String path);

/// Tests swap in their own reader.
@visibleForTesting
ImageTextReader? debugImageTextReader;

/// "Grab image text": reads the text in a picture on the phone itself, with
/// ML Kit's Latin-script model, so it also works offline. Returns the text a
/// line per line found, a blank line between blocks, or an empty string when
/// there is none.
Future<String> readImageText(String path) async {
  if (debugImageTextReader case final reader?) return reader(path);
  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    final result = await recognizer.processImage(InputImage.fromFilePath(path));
    return result.blocks
        .map((block) => block.lines.map((line) => line.text).join('\n'))
        .where((text) => text.trim().isNotEmpty)
        .join('\n\n')
        .trim();
  } finally {
    await recognizer.close();
  }
}
