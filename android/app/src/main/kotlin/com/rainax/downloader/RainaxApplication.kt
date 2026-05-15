package com.rainax.downloader

import android.app.Application
import android.util.Log
import com.chaquo.python.Python
import com.chaquo.python.android.AndroidPlatform

class RainaxApplication : Application() {
    override fun onCreate() {
        super.onCreate()

        // Start Chaquopy CPython runtime as early as possible.
        // This loads the embedded Python interpreter and makes yt-dlp importable.
        if (!Python.isStarted()) {
            Python.start(AndroidPlatform(this))
            Log.i("RAINAX", "Chaquopy Python runtime started ✓")
        }

        YtDlpBridge.init(this)
    }
}
