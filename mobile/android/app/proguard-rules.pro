# ML Kit text recognition ("Grab image text") ships only the Latin-script
# model; the plugin also refers to the optional Chinese, Devanagari, Japanese
# and Korean ones, which are not bundled.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# ML Kit creates its components by reflection, from class names listed in the
# manifest. Without this, R8 drops their constructors as unused, ML Kit starts
# without its text recognizer, and every "Grab image text" fails.
-keep class com.google.mlkit.**.*Registrar { <init>(); }
