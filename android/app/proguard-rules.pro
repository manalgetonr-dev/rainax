# Keep yt-dlp / Chaquopy Python classes
-keep class com.chaquo.python.** { *; }
-dontwarn com.chaquo.python.**

# Keep FFmpegKit
-keep class com.arthenica.ffmpegkit.** { *; }
-dontwarn com.arthenica.ffmpegkit.**

# Keep WorkManager
-keep class androidx.work.** { *; }

# Keep our own classes
-keep class com.rainax.downloader.** { *; }

# Kotlin serialization
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.AnnotationsKt

# OkHttp
-dontwarn okhttp3.**
-dontwarn okio.**
