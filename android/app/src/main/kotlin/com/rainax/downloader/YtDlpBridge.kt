package com.rainax.downloader

import android.util.Log
import com.chaquo.python.PyException
import com.chaquo.python.Python
import com.chaquo.python.android.AndroidPlatform
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.Executors
import java.util.concurrent.Future
import java.util.concurrent.TimeUnit
import java.util.concurrent.TimeoutException

/**
 * YtDlpBridge — Kotlin ↔ Chaquopy bridge for yt-dlp.
 *
 * ROOT CAUSE OF ANR / HANG:
 *   Original code used ONE single-thread executor for ALL Python calls.
 *   yt-dlp extract_info() on YouTube takes 10-30s on mobile.
 *   Android fires ANR after 5s if the Flutter platform channel is waiting.
 *   Result: app freezes then OS kills it — looks like a crash.
 *
 * FIX:
 *   1. fetchExecutor  — dedicated 2-thread pool for fetchInfo/getFormats.
 *      Wrapped with a 25s Future timeout so it ALWAYS returns an error
 *      instead of hanging forever.
 *   2. downloadExecutor — separate single-thread pool for downloads.
 *      Downloads are long background work; no ANR risk here.
 *   3. Python GIL: CPython only runs one thread at a time, but network
 *      I/O inside yt-dlp releases the GIL, so 2 fetch threads is safe.
 */
object YtDlpBridge {
    private const val TAG           = "YtDlpBridge"
    private const val FETCH_TIMEOUT = 25L   // seconds

    // 2-thread pool for interactive fetch calls
    private val fetchExecutor = Executors.newFixedThreadPool(2) { r ->
        Thread(r, "ytdlp-fetch").also { it.isDaemon = true }
    }

    // Single thread for long-running downloads
    private val downloadExecutor = Executors.newSingleThreadExecutor { r ->
        Thread(r, "ytdlp-download").also { it.isDaemon = true }
    }

    fun init(app: android.app.Application) {
        if (!Python.isStarted()) {
            Python.start(AndroidPlatform(app))
            Log.i(TAG, "Chaquopy Python ready")
        }
    }

    // ── Health check ──────────────────────────────────────────────────
    fun checkAvailable(callback: (Boolean) -> Unit) {
        fetchExecutor.execute {
            callback(runCatching {
                Python.getInstance().getModule("yt_dlp"); true
            }.getOrElse { false })
        }
    }

    // ── Metadata fetch — with 25s timeout ─────────────────────────────
    fun fetchInfo(url: String, callback: (Map<String, Any?>?, String?) -> Unit) {
        fetchExecutor.execute {
            val future: Future<*> = fetchExecutor.submit {
                try {
                    val raw = Python.getInstance()
                        .getModule("ytdlp_helper")
                        .callAttr("fetch_info", url).toString()
                    val obj = JSONObject(raw)
                    if (obj.has("error")) {
                        val err = obj.getString("error")
                        val tb  = if (obj.has("traceback"))
                                      "\n\nTraceback:\n${obj.getString("traceback")}" else ""
                        callback(null, err + tb)
                    } else {
                        callback(jsonToMap(obj), null)
                    }
                } catch (e: PyException) {
                    Log.e(TAG, "fetchInfo PyException: ${e.message}")
                    callback(null, "Python error: ${e.message}")
                } catch (e: Exception) {
                    Log.e(TAG, "fetchInfo Exception: ${e.message}")
                    callback(null, "Fetch error: ${e.message}")
                }
            }

            // Hard timeout — if Python is wedged we cancel and return error
            try {
                future.get(FETCH_TIMEOUT, TimeUnit.SECONDS)
            } catch (e: TimeoutException) {
                future.cancel(true)
                Log.e(TAG, "fetchInfo timed out for $url")
                callback(null,
                    "Timed out after ${FETCH_TIMEOUT}s. " +
                    "Possible causes: YouTube bot detection, slow network, " +
                    "or outdated yt-dlp. Try again or check logs.")
            } catch (e: Exception) {
                Log.e(TAG, "fetchInfo future error: ${e.message}")
                callback(null, "Internal error: ${e.message}")
            }
        }
    }

    // ── Format list — with 25s timeout ───────────────────────────────
    fun getFormats(url: String, callback: (List<Map<String, Any?>>?, String?) -> Unit) {
        fetchExecutor.execute {
            val future: Future<*> = fetchExecutor.submit {
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
            try {
                future.get(FETCH_TIMEOUT, TimeUnit.SECONDS)
            } catch (e: TimeoutException) {
                future.cancel(true)
                callback(null, "getFormats timed out after ${FETCH_TIMEOUT}s")
            } catch (e: Exception) {
                callback(null, "getFormats error: ${e.message}")
            }
        }
    }

    // ── Full download — no timeout, runs on downloadExecutor ──────────
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
        downloadExecutor.execute {
            val py  = Python.getInstance()
            val mod = py.getModule("ytdlp_helper")

            try {
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
                Log.e(TAG, "download PyException: ${e.message}")
                onError(taskId, e.message ?: "yt-dlp error")
            } catch (e: Exception) {
                Log.e(TAG, "download Exception: ${e.message}")
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
