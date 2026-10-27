# Flutter framework and embedding rules
-keep class io.flutter.** { *; }
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }

# Flutter plugins registration
-keep class io.flutter.plugins.** { *; }

# ML Kit Document Scanner & Vision Text rules
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
-keep class com.google.mlkit.vision.text.** { *; }

# Keep native JNI libraries & methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# AndroidX and Kotlin coroutines/reflection rules
-dontwarn kotlinx.coroutines.**
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod

# Play Core deferred components
-dontwarn com.google.android.play.core.**


