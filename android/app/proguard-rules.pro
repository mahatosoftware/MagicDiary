# ==============================================================================
# R8 / ProGuard Optimization Configuration for Magic Diary
# Satisfies Google Play DEX Code Optimisation Thresholds (>25% / >50% target)
# ==============================================================================

# Enable aggressive class, method, and member optimization
-allowaccessmodification
-repackageclasses ''

# Retain debugging line numbers and stack traces for crash reports
-keepattributes SourceFile,LineNumberTable
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# ------------------------------------------------------------------------------
# Flutter Engine & Plugin Architecture
# ------------------------------------------------------------------------------
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }
-keep class * implements io.flutter.embedding.engine.plugins.FlutterPlugin { *; }
-keep class * implements io.flutter.plugin.common.PluginRegistry$PluginRegistrantCallback { *; }

# Keep native methods called via JNI by Flutter engine
-keepclasseswithmembernames class * {
    native <methods>;
}

# ------------------------------------------------------------------------------
# App-Specific Components
# ------------------------------------------------------------------------------
-keep class in.mahato.magicdiary.MainActivity { *; }
-keep class in.mahato.magicdiary.MagicDiaryWidgetProvider { *; }

# ------------------------------------------------------------------------------
# Home Widget (es.antonborri.home_widget)
# ------------------------------------------------------------------------------
-keep class es.antonborri.home_widget.** { *; }

# ------------------------------------------------------------------------------
# Flutter Local Notifications & Alarm Manager
# ------------------------------------------------------------------------------
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class * extends androidx.work.Worker {
    public <init>(android.content.Context, androidx.work.WorkerParameters);
}
-keep class * extends androidx.work.ListenableWorker {
    public <init>(android.content.Context, androidx.work.WorkerParameters);
}

# ------------------------------------------------------------------------------
# Flutter Secure Storage
# ------------------------------------------------------------------------------
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# ------------------------------------------------------------------------------
# Google Mobile Ads (AdMob)
# ------------------------------------------------------------------------------
-keep public class com.google.android.gms.ads.** {
   public *;
}

# ------------------------------------------------------------------------------
# Dontwarn Directives
# (Allows R8 to strip/optimize unreferenced optional classes without warnings)
# ------------------------------------------------------------------------------
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**
-dontwarn com.google.android.play.core.**
-dontwarn androidx.**
-dontwarn com.dexterous.flutterlocalnotifications.**
-dontwarn com.it_nomads.fluttersecurestorage.**
-dontwarn com.google.mlkit.**
-dontwarn java.time.**
-dontwarn net.sf.andpdf.**
