#!/usr/bin/env bash
# Makes this checkout the F-Droid build, which F-Droid builds from source
# (the recipe in .github/fdroid/fdroiddata/): without ML Kit, which isn't
# free software, so without "Grab image text". The rest of the app is the
# same. Run from anywhere, before `flutter pub get`.
set -euo pipefail
cd "$(dirname "$0")/.."

cp lib/core/files/image_text_reader_none.dart lib/core/files/image_text_reader.dart
sed -i '/^  google_mlkit_text_recognition:/d' pubspec.yaml
# Its tests use ML Kit's types.
rm -f test/image_text_test.dart
