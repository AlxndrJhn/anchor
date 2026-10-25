# ML Kit text recognition ("Grab image text") ships only the Latin-script
# model; the plugin also refers to the optional Chinese, Devanagari, Japanese
# and Korean ones, which are not bundled.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
