# Flutter & ML Kit Proguard Rules

# Suppress warnings for unbundled ML Kit language packs
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
-dontwarn com.google.mlkit.vision.text.**
-dontwarn com.google_mlkit_text_recognition.**

# Suppress warnings for Google Play Core deferred components
-dontwarn com.google.android.play.core.**
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

# Keep ML Kit components
-keep class com.google.mlkit.** { *; }
-keep interface com.google.mlkit.** { *; }

# Keep Flutter wrapper & plugin classes
-keep class io.flutter.plugin.common.** { *; }
-keep class io.flutter.app.** { *; }
-keep class io.flutter.embedding.** { *; }

# Keep SQLite, SharedPreferences, and PathProvider plugins
-keep class com.tekartik.sqflite.** { *; }
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keep class io.flutter.plugins.pathprovider.** { *; }

# Keep native methods and annotations
-keepattributes *Annotation*
-keepclasseswithmembernames class * {
    native <methods>;
}
