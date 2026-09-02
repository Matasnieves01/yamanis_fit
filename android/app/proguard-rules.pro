# ProGuard rules for yamanis_fit

# Optimization for BitmapFactory (though it won't fix missing options, it ensures optimization is active)
-optimizations !code/simplification/arithmetic,!field/*,!class/merging/*

# Keep classes that might be accessed via reflection if necessary
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class com.google.firebase.** { *; }

# General optimizations
-repackageclasses ''
-allowaccessmodification
-mergeinterfacesaggressively

-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
