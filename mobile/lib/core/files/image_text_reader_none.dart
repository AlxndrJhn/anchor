import 'dart:ui';

// Stands in for image_text_reader.dart in the F-Droid build, which has no ML
// Kit (see tool/fdroid_prebuild.sh): "Grab image text" isn't offered there.

/// Whether this build can read the text in a picture.
const hasImageTextReader = false;

/// A picture's text: paragraphs of lines of words, each with its place in
/// the picture's pixels.
typedef TextBlocks = List<List<List<(String, Rect)>>>;

Future<TextBlocks> readImageText(String path) =>
    throw UnsupportedError('This build can\'t read the text in pictures');
