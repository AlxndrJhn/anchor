import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// "Grab image text": reads the text in a picture on the phone itself, with
/// ML Kit's Latin-script model. Returns the text a line per line found, or
/// an empty string when there is none.
Future<String> readImageText(String path) async {
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
