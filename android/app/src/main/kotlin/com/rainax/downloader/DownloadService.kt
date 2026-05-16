package com.rainax.downloader

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import io.flutter.plugin.common.EventChannel
import kotlinx.coroutines.*
import java.io.File
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicInteger

/**
 * DownloadService – Foreground service that survives app minimisation.
 *
 * FIX 5: totalActive is now AtomicInteger — was a plain Int mutated from
 *        multiple coroutines, causing a race condition / wrong count.
 * FIX 6: sendEvent posts to Main dispatcher safely; added null-check guard
 *        so a stale progressSink never causes an IllegalStateException.
 * FIX 7: onDestroy cancels scope before super — prevents coroutine leaks
 *        from delivering events after service is destroyed.
 * FIX 8: defaultOutputDir() now uses getExternalFilesDir which is always
 *        accessible without WRITE_EXTERNAL_STORAGE on API 29+.
 */
class DownloadService : Service() {

    companion object {
        const val ACTION_START  = "RAINAX_START"
        const val ACTION_CANCEL = "RAINAX_CANCEL"
        const val ACTION_PAUSE  = "RAINAX_PAUSE"
        const val ACTION_RESUME = "RAINAX_RESUME"
        const val CHANNEL_ID    = "rainax_downloads"
        const val NOTIF_ID      = 1001
        private  const val TAG  = "DownloadService"

        @Volatile var progressSink: EventChannel.EventSink? = null

        private val cancelFlags = ConcurrentHashMap<String, Boolean>()
        private val pauseFlags  = ConcurrentHashMap<String, Boolean>()

        fun pauseTask(taskId: String)  { pauseFlags[taskId]  = true  }
        fun resumeTask(taskId: String) { pauseFlags[taskId]  = false }
        fun cancelTask(taskId: String) { cancelFlags[taskId] = true; pauseFlags.remove(taskId) }
        fun getActiveTaskIds(): List<String> = cancelFlags.keys.toList()
    }

    private val scope        = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val activeTasks  = ConcurrentHashMap<String, Job>()
    // FIX 5: AtomicInteger prevents race on concurrent downloads
    private val totalActive  = AtomicInteger(0)

    // ── Service lifecycle ─────────────────────────────────────────────

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startForeground(NOTIF_ID, buildNotification("RAINAX ready", "", 0, false))
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START  -> handleStart(intent)
            ACTION_PAUSE  -> pauseTask(intent.getStringExtra("taskId") ?: "")
            ACTION_RESUME -> resumeTask(intent.getStringExtra("taskId") ?: "")
            ACTION_CANCEL -> cancelTask(intent.getStringExtra("taskId") ?: "")
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        // FIX 7: cancel scope BEFORE super so no events fire after destroy
        scope.cancel()
        super.onDestroy()
    }

    // ── Start a download ──────────────────────────────────────────────

    private fun handleStart(intent: Intent) {
        val taskId    = intent.getStringExtra("taskId")    ?: return
        val url       = intent.getStringExtra("url")       ?: return
        val format    = intent.getStringExtra("format")    ?: "bv*+ba/b"
        val outputDir = intent.getStringExtra("outputDir") ?: defaultOutputDir()
        val audioOnly = intent.getBooleanExtra("audioOnly", false)
        val mp3       = intent.getBooleanExtra("mp3",       false)
        val playlist  = intent.getBooleanExtra("playlist",  false)

        cancelFlags[taskId] = false
        pauseFlags[taskId]  = false
        totalActive.incrementAndGet()  // FIX 5

        sendEvent(taskId, 0f, "", "", "", "STARTING")

        val job = scope.launch {
            YtDlpBridge.download(
                taskId    = taskId,
                url       = url,
                formatStr = format,
                outputDir = outputDir,
                audioOnly = audioOnly,
                mp3       = mp3,
                playlist  = playlist,
                onProgress = { id, pct, speed, eta, filename ->
                    sendEvent(id, pct, speed, eta, filename, "RUNNING")
                    updateNotification(id, pct, filename)
                },
                onComplete = { id, filePath ->
                    totalActive.decrementAndGet()  // FIX 5
                    sendEvent(id, 100f, "", "", filePath, "COMPLETED", filePath)
                    notifyComplete(id, filePath)
                    cleanup(id)
                },
                onError = { id, msg ->
                    totalActive.decrementAndGet()  // FIX 5
                    sendEvent(id, 0f, "", "", "", "FAILED", msg)
                    notifyError(id, msg)
                    cleanup(id)
                },
                cancelCheck = { cancelFlags[taskId] == true },
                pauseCheck  = { pauseFlags[taskId]  == true }
            )
        }
        activeTasks[taskId] = job
    }

    private fun cleanup(taskId: String) {
        activeTasks.remove(taskId)
        cancelFlags.remove(taskId)
        pauseFlags.remove(taskId)
        if (totalActive.get() == 0) {
            updateNotification("", 0f, "All downloads complete")
        }
    }

    // ── Flutter event dispatch ────────────────────────────────────────

    private fun sendEvent(
        taskId: String, percent: Float, speed: String, eta: String,
        filename: String, status: String, extra: String = ""
    ) {
        val event = mapOf(
            "taskId"   to taskId,
            "percent"  to percent,
            "speed"    to speed,
            "eta"      to eta,
            "filename" to filename,
            "status"   to status,
            "filePath" to if (status == "COMPLETED") extra else "",
            "error"    to if (status == "FAILED")    extra else "",
            "ts"       to System.currentTimeMillis()
        )
        // FIX 6: capture sink locally to avoid TOCTOU null-pointer
        val sink = progressSink
        if (sink == null) return
        scope.launch(Dispatchers.Main) {
            try { sink.success(event) }
            catch (e: Exception) { Log.w(TAG, "EventSink post failed: ${e.message}") }
        }
    }

    // ── Notifications ─────────────────────────────────────────────────

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            getSystemService(NotificationManager::class.java)
                .createNotificationChannel(
                    NotificationChannel(
                        CHANNEL_ID,
                        "RAINAX Downloads",
                        NotificationManager.IMPORTANCE_LOW
                    ).apply {
                        description = "Active download progress"
                        setShowBadge(true)
                    })
        }
    }

    private fun buildNotification(
        title: String, text: String, progress: Int, indeterminate: Boolean
    ): Notification {
        val openPi = PendingIntent.getActivity(
            this, 0, Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(text)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setOngoing(true)
            .setProgress(100, progress, indeterminate)
            .setContentIntent(openPi)
            .setSilent(true)
            .build()
    }

    private fun updateNotification(taskId: String, percent: Float, filename: String) {
        val nm   = NotificationManagerCompat.from(this)
        val name = File(filename).nameWithoutExtension.take(38).ifEmpty {
            if (totalActive.get() > 1) "${totalActive.get()} active downloads" else "Downloading…"
        }
        val notif = buildNotification(
            title         = "RAINAX  ·  ${percent.toInt()}%",
            text          = name,
            progress      = percent.toInt(),
            indeterminate = percent == 0f
        )
        try { nm.notify(NOTIF_ID, notif) } catch (_: SecurityException) {}
    }

    private fun notifyComplete(taskId: String, filePath: String) {
        val nm   = NotificationManagerCompat.from(this)
        val name = File(filePath).name.take(50)
        val notif = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Download complete ✓")
            .setContentText(name)
            .setSmallIcon(android.R.drawable.stat_sys_download_done)
            .setAutoCancel(true)
            .setSilent(false)
            .build()
        try { nm.notify(taskId.hashCode(), notif) } catch (_: SecurityException) {}
    }

    private fun notifyError(taskId: String, error: String) {
        val nm   = NotificationManagerCompat.from(this)
        val notif = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Download failed")
            .setContentText(error.take(80))
            .setSmallIcon(android.R.drawable.stat_notify_error)
            .setAutoCancel(true)
            .build()
        try { nm.notify(taskId.hashCode(), notif) } catch (_: SecurityException) {}
    }

    // FIX 8: getExternalFilesDir is scoped storage, no WRITE permission needed on API 29+
    private fun defaultOutputDir(): String {
        val dir = File(getExternalFilesDir(null), "RAINAX/Downloads")
        dir.mkdirs()
        return dir.absolutePath
    }
}
