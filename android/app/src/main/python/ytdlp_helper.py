"""
ytdlp_helper.py
───────────────
Python helper loaded by Chaquopy inside the Android APK.
Provides fetch_info, get_formats, and run_download_kotlin.

All functions return JSON strings so they cross the JNI boundary cleanly.
Progress events for run_download_kotlin are delivered via a module-level
dict keyed by taskId; Kotlin polls or receives them via the EventChannel.
"""
from __future__ import annotations

import json
import os
import sys
import stat
import traceback
from typing import Any

import yt_dlp

# ── Bootstrap ffmpeg from app assets ─────────────────────────────────────────
# The ffmpeg binary is copied from APK assets into the app's files dir by
# Kotlin (RainaxApplication) before Python starts. We just need to ensure
# it's on PATH so yt-dlp post-processors can find it.
def _setup_ffmpeg() -> None:
    possible = []
    # Search sys.path for the app's private files directory
    for p in sys.path:
        if "com.rainax.downloader" in p:
            base = p.split("com.rainax.downloader")[0] + "com.rainax.downloader"
            possible.append(os.path.join(base, "files", "ffmpeg"))

    # Also check common Android data paths
    for env_var in ("ANDROID_DATA", "EXTERNAL_STORAGE"):
        val = os.environ.get(env_var, "")
        if val and "com.rainax.downloader" in val:
            possible.append(os.path.join(val, "files", "ffmpeg"))

    for ffmpeg_path in possible:
        if os.path.isfile(ffmpeg_path):
            os.chmod(ffmpeg_path, os.stat(ffmpeg_path).st_mode | stat.S_IEXEC)
            ffmpeg_dir = os.path.dirname(ffmpeg_path)
            current_path = os.environ.get("PATH", "")
            if ffmpeg_dir not in current_path:
                os.environ["PATH"] = ffmpeg_dir + ":" + current_path
            print(f"[RAINAX] ffmpeg found at {ffmpeg_path}", file=sys.stderr)
            return

    print("[RAINAX] ffmpeg binary not found — audio conversion will be skipped", file=sys.stderr)

_setup_ffmpeg()

# ── Module-level progress registry ───────────────────────────────────────────
# Kotlin registers a callback here before calling run_download_kotlin.
# Maps  taskId (str) → callable(percent, speed, eta, filename)
_progress_callbacks: dict[str, Any] = {}

def register_progress_callback(task_id: str, cb) -> None:
    _progress_callbacks[task_id] = cb

def unregister_progress_callback(task_id: str) -> None:
    _progress_callbacks.pop(task_id, None)


# ── Logger ────────────────────────────────────────────────────────────────────
class _QuietLogger:
    def debug(self, msg):   pass
    def info(self, msg):    pass
    def warning(self, msg): pass
    def error(self, msg):   print(f"[yt-dlp] {msg}", file=sys.stderr)


# ── JSON helpers ──────────────────────────────────────────────────────────────
def _clean(obj: Any) -> Any:
    if isinstance(obj, dict):
        return {k: _clean(v) for k, v in obj.items() if isinstance(k, str)}
    if isinstance(obj, (list, tuple)):
        return [_clean(i) for i in obj]
    if isinstance(obj, (int, float, bool, str)) or obj is None:
        return obj
    return str(obj)

def _json(obj: Any) -> str:
    return json.dumps(_clean(obj), ensure_ascii=False)


# ── Public API ────────────────────────────────────────────────────────────────

def fetch_info(url: str) -> str:
    """Return JSON with title, thumbnail, duration, uploader, is_playlist, entries."""
    opts = {
        "quiet": True, "no_warnings": True, "logger": _QuietLogger(),
        "extract_flat": True, "skip_download": True,
        "socket_timeout": 20, "retries": 3, "ignoreerrors": True,
    }
    try:
        with yt_dlp.YoutubeDL(opts) as ydl:
            info = ydl.extract_info(url, download=False)
        if info is None:
            return _json({"error": "No info returned"})

        entries = []
        for e in (info.get("entries") or []):
            if e:
                entries.append({
                    "id":        e.get("id", ""),
                    "title":     e.get("title", ""),
                    "url":       e.get("url") or e.get("webpage_url", ""),
                    "duration":  e.get("duration"),
                    "thumbnail": e.get("thumbnail", ""),
                })

        return _json({
            "title":       info.get("title", ""),
            "thumbnail":   info.get("thumbnail", ""),
            "duration":    info.get("duration"),
            "uploader":    info.get("uploader") or info.get("channel", ""),
            "webpage_url": info.get("webpage_url", url),
            "is_playlist": bool(entries),
            "entry_count": len(entries),
            "entries":     entries[:200],
        })
    except Exception as exc:
        return _json({"error": str(exc)})


def get_formats(url: str) -> str:
    """Return JSON array of available formats."""
    opts = {
        "quiet": True, "no_warnings": True, "logger": _QuietLogger(),
        "skip_download": True, "socket_timeout": 20,
    }
    try:
        with yt_dlp.YoutubeDL(opts) as ydl:
            info = ydl.extract_info(url, download=False)
        if not info:
            return "[]"
        formats = []
        for f in (info.get("formats") or []):
            vcodec = f.get("vcodec", "none") or "none"
            acodec = f.get("acodec", "none") or "none"
            formats.append({
                "format_id":  f.get("format_id", ""),
                "ext":        f.get("ext", ""),
                "quality":    f.get("quality"),
                "height":     f.get("height"),
                "fps":        f.get("fps"),
                "vcodec":     vcodec,
                "acodec":     acodec,
                "filesize":   f.get("filesize") or f.get("filesize_approx"),
                "tbr":        f.get("tbr"),
                "abr":        f.get("abr"),
                "audio_only": vcodec == "none" and acodec != "none",
                "video_only": acodec == "none" and vcodec != "none",
                "label":      f.get("format", ""),
            })
        return _json(formats)
    except Exception:
        return "[]"


def run_download_kotlin(
    url:        str,
    format_str: str,
    output_dir: str,
    audio_only: bool,
    mp3:        bool,
    playlist:   bool,
    task_id:    str,
) -> str:
    """
    Execute a full yt-dlp download.

    Progress events are dispatched to the registered callback for task_id.
    Returns JSON: {"success": true, "file_path": "..."} or {"success": false, "error": "..."}
    """
    os.makedirs(output_dir, exist_ok=True)
    tmp_dir = os.path.join(output_dir, ".tmp")
    os.makedirs(tmp_dir, exist_ok=True)

    outtmpl = os.path.join(output_dir, "%(title)s.%(ext)s")

    # Only add ffmpeg post-processors if ffmpeg is actually available
    import shutil
    ffmpeg_available = shutil.which("ffmpeg") is not None
    postprocessors = []
    if ffmpeg_available:
        if mp3:
            postprocessors += [
                {"key": "FFmpegExtractAudio", "preferredcodec": "mp3", "preferredquality": "192"},
                {"key": "FFmpegMetadata"},
            ]
        elif audio_only:
            postprocessors += [
                {"key": "FFmpegExtractAudio", "preferredcodec": "m4a"},
                {"key": "FFmpegMetadata"},
            ]

    last_file = {"path": ""}
    cb = _progress_callbacks.get(task_id)

    def progress_hook(d: dict) -> None:
        filename = d.get("filename", "") or last_file["path"]
        if filename:
            last_file["path"] = filename
        status = d.get("status", "")
        if status == "downloading" and cb is not None:
            try:
                pct_str = (d.get("_percent_str") or "0").strip().rstrip("%")
                pct     = float(pct_str) if pct_str else 0.0
                speed   = (d.get("_speed_str") or "--").strip()
                eta     = (d.get("_eta_str") or "--").strip()
                cb(pct, speed, eta, filename)
            except Exception:
                pass

    opts: dict = {
        "format":            format_str,
        "outtmpl":           outtmpl,
        "quiet":             True,
        "no_warnings":       True,
        "logger":            _QuietLogger(),
        "progress_hooks":    [progress_hook],
        "postprocessors":    postprocessors,
        "socket_timeout":    30,
        "retries":           5,
        "fragment_retries":  10,
        "concurrent_fragment_downloads": 4,
        "ignoreerrors":      playlist,
        "noplaylist":        not playlist,
        "part":              True,
        "merge_output_format": "mp4",
        "paths":             {"temp": tmp_dir},
    }

    try:
        with yt_dlp.YoutubeDL(opts) as ydl:
            ydl.download([url])
        return _json({"success": True, "file_path": last_file["path"]})
    except yt_dlp.utils.DownloadError as exc:
        return _json({"success": False, "error": str(exc)})
    except Exception as exc:
        tb = traceback.format_exc()
        return _json({"success": False, "error": f"{exc}\n{tb[:400]}"})


# ── Kotlin callback bridge ────────────────────────────────────────────────────
def _make_kotlin_hook(kotlin_cb):
    """
    Wrap a Kotlin ProgressCallback (Java interface proxy) as a Python callable.
    Chaquopy allows Java interface implementations to be called from Python
    by invoking the interface method directly.
    """
    def hook(pct: float, speed: str, eta: str, filename: str) -> None:
        try:
            kotlin_cb.onProgress(pct, speed, eta, filename)
        except Exception:
            pass
    return hook
