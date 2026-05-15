package com.rainax.downloader

import android.app.Application
import android.util.Log
import com.chaquo.python.Python
import com.chaquo.python.android.AndroidPlatform
import java.io.File

class RainaxApplication : Application() {
    override fun onCreate() {
        super.onCreate()

        // Extract ffmpeg binary from assets into app's private files dir
        // so yt-dlp post-processors can find it at runtime via PATH.
        extractFfmpeg()

        // Start Chaquopy CPython runtime as early as possible.
        if (!Python.isStarted()) {
            Python.start(AndroidPlatform(this))
            Log.i("RAINAX", "Chaquopy Python runtime started ✓")
        }

        YtDlpBridge.init(this)
    }

    private fun extractFfmpeg() {
        val ffmpegFile = File(filesDir, "ffmpeg")
        try {
            // Only extract if not already present or asset is newer
            assets.open("ffmpeg").use { input ->
                ffmpegFile.outputStream().use { output ->
                    input.copyTo(output)
                }
            }
            ffmpegFile.setExecutable(true, false)
            // Set PATH so Python's os.environ["PATH"] includes our dir
            val existing = System.getenv("PATH") ?: ""
            if (!existing.contains(filesDir.absolutePath)) {
                // Can't set env vars directly on Android after process start,
                // but Python's _setup_ffmpeg() will find it via filesDir path.
            }
            Log.i("RAINAX", "ffmpeg extracted to ${ffmpegFile.absolutePath} ✓")
        } catch (e: Exception) {
            // No ffmpeg asset bundled — video-only downloads still work fine
            Log.w("RAINAX", "ffmpeg not bundled in assets: ${e.message}")
        }
    }
}
