# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Google Sign-In
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# SQLite
-keep class org.sqlite.** { *; }
-keep class org.sqlite.database.** { *; }

# Google Play Core (deferred components)
-dontwarn com.google.android.play.core.**

# Health Connect
-keep class androidx.health.connect.** { *; }
-dontwarn androidx.health.connect.**

# Keep model classes used with JSON serialization
-keepattributes *Annotation*
-keepattributes Signature
