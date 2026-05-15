package com.rainax.downloader

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        const val DOWNLOAD_CHANNEL = "com.rainax.downloader/download"
        const val PROGRESS_CHANNEL = "com.rainax.downloader/progress"
        const val YTDLP_CHANNEL    = "com.rainax.downloader/ytdlp"
        const val REQ_PERMISSIONS  = 1001
    }

    private var progressSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── Download control channel ───────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DOWNLOAD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {

                    "startDownload" -> {
                        val args = call.arguments as Map<*, *>
                        val intent = Intent(this, DownloadService::class.java).apply {
                            action = DownloadService.ACTION_START
                            putExtra("taskId",    args["taskId"] as? String ?: "")
                            putExtra("url",       args["url"] as? String ?: "")
                            putExtra("format",    args["format"] as? String ?: "bv*+ba/b")
                            putExtra("outputDir", args["outputDir"] as? String ?: "")
                            putExtra("audioOnly", args["audioOnly"] as? Boolean ?: false)
                            putExtra("mp3",       args["mp3"] as? Boolean ?: false)
                            putExtra("playlist",  args["playlist"] as? Boolean ?: false)
                            putExtra("quality",   args["quality"] as? String ?: "best")
                        }
                        try {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                startForegroundService(intent)
                            } else {
                                startService(intent)
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            android.util.Log.e("MainActivity", "startForegroundService failed: ${e.message}")
                            result.error("SERVICE_ERROR", e.message, null)
                        }
                    }

                    "pauseDownload" -> {
                        val taskId = call.argument<String>("taskId") ?: ""
                        DownloadService.pauseTask(taskId)
                        result.success(true)
                    }

                    "resumeDownload" -> {
                        val taskId = call.argument<String>("taskId") ?: ""
                        DownloadService.resumeTask(taskId)
                        result.success(true)
                    }

                    "cancelDownload" -> {
                        val taskId = call.argument<String>("taskId") ?: ""
                        DownloadService.cancelTask(taskId)
                        result.success(true)
                    }

                    "getActiveDownloads" -> {
                        result.success(DownloadService.getActiveTaskIds())
                    }

                    "requestPermissions" -> {
                        requestStoragePermissions()
                        result.success(true)
                    }

                    "stopService" -> {
                        stopService(Intent(this, DownloadService::class.java))
                        result.success(true)
                    }

                    else -> result.notImplemented()
                }
            }

        // ── yt-dlp info / metadata channel ────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, YTDLP_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {

                    "fetchInfo" -> {
                        val url = call.argument<String>("url") ?: ""
                        YtDlpBridge.fetchInfo(url) { info, err ->
                            runOnUiThread {
                                if (err != null) result.error("YTDLP_ERROR", err, null)
                                else result.success(info)
                            }
                        }
                    }

                    "getFormats" -> {
                        val url = call.argument<String>("url") ?: ""
                        YtDlpBridge.getFormats(url) { formats, err ->
                            runOnUiThread {
                                if (err != null) result.error("YTDLP_ERROR", err, null)
                                else result.success(formats)
                            }
                        }
                    }

                    "checkYtDlp" -> {
                        YtDlpBridge.checkAvailable { ok ->
                            runOnUiThread { result.success(ok) }
                        }
                    }

                    else -> result.notImplemented()
                }
            }

        // ── Real-time progress EventChannel ───────────────────────────
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, PROGRESS_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    progressSink = events
                    DownloadService.progressSink = events
                }
                override fun onCancel(arguments: Any?) {
                    progressSink = null
                    DownloadService.progressSink = null
                }
            })
    }

    // ── Runtime permissions ───────────────────────────────────────────

    private fun requestStoragePermissions() {
        val permsNeeded = mutableListOf<String>()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            // Android 13+: granular media permissions
            listOf(
                Manifest.permission.READ_MEDIA_VIDEO,
                Manifest.permission.READ_MEDIA_AUDIO,
                Manifest.permission.POST_NOTIFICATIONS
            ).forEach { p ->
                if (ContextCompat.checkSelfPermission(this, p) != PackageManager.PERMISSION_GRANTED) {
                    permsNeeded.add(p)
                }
            }
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            // Android 10–12: READ_EXTERNAL_STORAGE (write is scoped)
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_EXTERNAL_STORAGE)
                != PackageManager.PERMISSION_GRANTED) {
                permsNeeded.add(Manifest.permission.READ_EXTERNAL_STORAGE)
            }
        } else {
            // Android 9 and below: both read and write
            listOf(
                Manifest.permission.READ_EXTERNAL_STORAGE,
                Manifest.permission.WRITE_EXTERNAL_STORAGE
            ).forEach { p ->
                if (ContextCompat.checkSelfPermission(this, p) != PackageManager.PERMISSION_GRANTED) {
                    permsNeeded.add(p)
                }
            }
        }

        if (permsNeeded.isNotEmpty()) {
            ActivityCompat.requestPermissions(this, permsNeeded.toTypedArray(), REQ_PERMISSIONS)
        }
    }

    // ── Share intent handling ─────────────────────────────────────────

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleSharedIntent(intent)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleSharedIntent(intent)
    }

    private fun handleSharedIntent(intent: Intent?) {
        if (intent?.action == Intent.ACTION_SEND && intent.type == "text/plain") {
            val sharedUrl = intent.getStringExtra(Intent.EXTRA_TEXT) ?: return
            flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                MethodChannel(messenger, DOWNLOAD_CHANNEL)
                    .invokeMethod("onSharedUrl", mapOf("url" to sharedUrl))
            }
        }
    }
}
