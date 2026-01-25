# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep generic Flutter/Dart interactions
-keepattributes SourceFile,LineNumberTable
-keep public class * extends io.flutter.plugin.common.PluginRegistry$Registrar

# Prevent Shared Preferences issues
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Fix for R8 Missing Class Errors (Google Play Core)
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.*