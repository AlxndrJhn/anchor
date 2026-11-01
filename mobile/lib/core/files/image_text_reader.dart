import 'dart:ui';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

// The only file that uses ML Kit, which isn't free software: the F-Droid
// build (tool/fdroid_prebuild.sh) puts image_text_reader_none.dart in its
// place and drops the package.

/// Whether this build can read the text in a picture.
const hasImageTextReader = true;

/// A picture's text: paragraphs of lines of words, each with its place in
/// the picture's pixels.
typedef TextBlocks = List<List<List<(String, Rect)>>>;

/// Reads the text in the picture at a path, on the phone itself, with ML
/// Kit's Latin-script model, so it also works offline.
Future<TextBlocks> readImageText(String path) async {
  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    return textBlocksOf(
      await recognizer.processImage(InputImage.fromFilePath(path)),
    );
  } finally {
    await recognizer.close();
  }
}

/// ML Kit's answer as paragraphs of lines of words; a line ML Kit didn't
/// split is one word.
TextBlocks textBlocksOf(RecognizedText result) => [
  for (final block in result.blocks)
    [
      for (final line in block.lines)
        line.elements.isEmpty
            ? [(line.text, line.boundingBox)]
            : [for (final e in line.elements) (e.text, e.boundingBox)],
    ],
];
