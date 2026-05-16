package com.rainax.downloader

import android.app.Application
import android.util.Log
import java.io.File

class RainaxApplication : Application() {
    override fun onCreate() {
        super.onCreate()

        // Extract ffmpeg binary BEFORE Python starts (Python _setup_ffmpeg reads PATH)
        extractFfmpeg()

        // FIX: Only call YtDlpBridge.init() once — it already guards Python.isStarted()
        // Removed duplicate Python.start() that was here before
        YtDlpBridge.init(this)
    }

    private fun extractFfmpeg() {
        val ffmpegFile = File(filesDir, "ffmpeg")
        try {
            assets.open("ffmpeg").use { input ->
                ffmpegFile.outputStream().use { output ->
                    input.copyTo(output)
                }
            }
            ffmpegFile.setExecutable(true, false)
            Log.i("RAINAX", "ffmpeg extracted to ${ffmpegFile.absolutePath} ✓")
        } catch (e: Exception) {
            // No ffmpeg asset bundled — video-only downloads still work fine
            Log.w("RAINAX", "ffmpeg not bundled in assets: ${e.message}")
        }
    }
}
