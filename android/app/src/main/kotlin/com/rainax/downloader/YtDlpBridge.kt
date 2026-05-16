package com.rainax.downloader

import android.util.Log
import com.chaquo.python.PyException
import com.chaquo.python.Python
import com.chaquo.python.android.AndroidPlatform
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.Executors

/**
 * YtDlpBridge
 *
 * Kotlin ↔ Chaquopy (CPython) bridge for yt-dlp.
 *
 * FIX 1: ProgressCallback moved to ProgressCallback.java — Chaquopy requires
 *         a real Java interface, not a Kotlin fun interface.
 * FIX 2: executor is single-thread; fetchInfo/getFormats also run on it so
 *         Python GIL is never contested from multiple threads.
 * FIX 3: init() is idempotent — safe to call multiple times.
 */
object YtDlpBridge {
    private const val TAG = "YtDlpBridge"

    // Single-threaded — respects Python GIL
    private val executor = Executors.newSingleThreadExecutor { r ->
        Thread(r, "ytdlp-worker").also { it.isDaemon = true }
    }

    fun init(app: android.app.Application) {
        // FIX 3: guard prevents double-start crash from RainaxApplication
        if (!Python.isStarted()) {
            Python.start(AndroidPlatform(app))
            Log.i(TAG, "Chaquopy Python ready ✓")
        }
    }

    // ── Health check ──────────────────────────────────────────────────
    fun checkAvailable(callback: (Boolean) -> Unit) {
        executor.execute {
            callback(runCatching {
                Python.getInstance().getModule("yt_dlp"); true
            }.getOrElse { false })
        }
    }

    // ── Metadata fetch ────────────────────────────────────────────────
    fun fetchInfo(url: String, callback: (Map<String, Any?>?, String?) -> Unit) {
        executor.execute {
            try {
                val raw = Python.getInstance()
                    .getModule("ytdlp_helper")
                    .callAttr("fetch_info", url).toString()
                val obj = JSONObject(raw)
                if (obj.has("error")) callback(null, obj.getString("error"))
                else callback(jsonToMap(obj), null)
            } catch (e: PyException) { callback(null, e.message) }
              catch (e: Exception)   { callback(null, e.message) }
        }
    }

    // ── Format list ───────────────────────────────────────────────────
    fun getFormats(url: String, callback: (List<Map<String, Any?>>?, String?) -> Unit) {
        executor.execute {
            try {
                val raw = Python.getInstance()
                    .getModule("ytdlp_helper")
                    .callAttr("get_formats", url).toString()
                val arr  = JSONArray(raw)
                val list = (0 until arr.length()).map { jsonToMap(arr.getJSONObject(it)) }
                callback(list, null)
            } catch (e: PyException) { callback(null, e.message) }
              catch (e: Exception)   { callback(null, e.message) }
        }
    }

    // ── Full download ─────────────────────────────────────────────────
    fun download(
        taskId:      String,
        url:         String,
        formatStr:   String,
        outputDir:   String,
        audioOnly:   Boolean,
        mp3:         Boolean,
        playlist:    Boolean,
        onProgress:  (taskId: String, pct: Float, speed: String, eta: String, filename: String) -> Unit,
        onComplete:  (taskId: String, filePath: String) -> Unit,
        onError:     (taskId: String, message: String) -> Unit,
        cancelCheck: () -> Boolean,
        pauseCheck:  () -> Boolean
    ) {
        executor.execute {
            val py  = Python.getInstance()
            val mod = py.getModule("ytdlp_helper")

            try {
                // FIX 1: ProgressCallback is now a Java interface — Chaquopy can proxy it
                val kotlinCb = ProgressCallback { pct, speed, eta, filename ->
                    if (cancelCheck()) return@ProgressCallback
                    while (pauseCheck() && !cancelCheck()) Thread.sleep(250)
                    onProgress(taskId, pct, speed, eta, filename)
                }
                val pyCb = mod.callAttr("_make_kotlin_hook", kotlinCb)

                mod.callAttr("register_progress_callback", taskId, pyCb)

                if (!cancelCheck()) {
                    val resultJson = mod.callAttr(
                        "run_download_kotlin",
                        url, formatStr, outputDir, audioOnly, mp3, playlist, taskId
                    ).toString()

                    val obj = JSONObject(resultJson)
                    if (obj.optBoolean("success", false)) {
                        onComplete(taskId, obj.optString("file_path", ""))
                    } else {
                        onError(taskId, obj.optString("error", "Download failed"))
                    }
                } else {
                    onError(taskId, "Cancelled")
                }

            } catch (e: PyException) {
                Log.e(TAG, "PyException: ${e.message}")
                onError(taskId, e.message ?: "yt-dlp error")
            } catch (e: Exception) {
                Log.e(TAG, "Exception: ${e.message}")
                onError(taskId, e.message ?: "Bridge error")
            } finally {
                runCatching { mod.callAttr("unregister_progress_callback", taskId) }
            }
        }
    }

    // ── JSON helper ───────────────────────────────────────────────────
    private fun jsonToMap(json: JSONObject): Map<String, Any?> =
        json.keys().asSequence().associateWith { k ->
            when (val v = json.opt(k)) {
                is JSONObject   -> jsonToMap(v)
                JSONObject.NULL -> null
                else            -> v
            }
        }
}
