"""
ytdlp_helper.py
───────────────
Python helper loaded by Chaquopy inside the Android APK.

FIX 9:  _setup_ffmpeg() now also checks filesDir via a reliable env var
        (PYTHONPATH contains the app private path on Chaquopy).
FIX 10: fetch_info uses extract_flat='in_playlist' instead of True so
        single-video URLs get full metadata (duration, thumbnail, etc.)
        instead of returning a flat stub with no useful fields.
FIX 11: get_formats catches DownloadError specifically so a bad URL
        returns [] gracefully instead of crashing the bridge.
FIX 12: run_download_kotlin catches yt_dlp.utils.DownloadError and
        generic Exception separately and always returns valid JSON —
        no unhandled exception can escape to crash the JNI bridge.
FIX 13: progress_hook guards against missing/malformed _percent_str
        more robustly (handles ANSI escape codes yt-dlp sometimes emits).
"""
from __future__ import annotations

import json
import os
import re
import sys
import stat
import traceback
from typing import Any

import yt_dlp

# ── Bootstrap ffmpeg ──────────────────────────────────────────────────────────
def _setup_ffmpeg() -> None:
    candidates: list[str] = []

    # Chaquopy adds the app's private files dir to PYTHONPATH
    for p in sys.path:
        if "com.rainax.downloader" in p:
            base = p.split("com.rainax.downloader")[0] + "com.rainax.downloader"
            candidates.append(os.path.join(base, "files", "ffmpeg"))

    # FIX 9: Also try the standard Android data directory pattern
    android_data = os.environ.get("ANDROID_DATA", "/data")
    candidates.append(
        os.path.join(android_data, "data", "com.rainax.downloader", "files", "ffmpeg")
    )

    for ffmpeg_path in candidates:
        if os.path.isfile(ffmpeg_path):
            try:
                os.chmod(ffmpeg_path, os.stat(ffmpeg_path).st_mode | stat.S_IEXEC | stat.S_IXGRP | stat.S_IXOTH)
            except OSError:
                pass
            ffmpeg_dir = os.path.dirname(ffmpeg_path)
            current_path = os.environ.get("PATH", "")
            if ffmpeg_dir not in current_path:
                os.environ["PATH"] = ffmpeg_dir + ":" + current_path
            print(f"[RAINAX] ffmpeg found at {ffmpeg_path}", file=sys.stderr)
            return

    print("[RAINAX] ffmpeg binary not found — audio conversion will be skipped", file=sys.stderr)

_setup_ffmpeg()

# ── Module-level progress registry ───────────────────────────────────────────
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

# FIX 13: strip ANSI codes that yt-dlp sometimes embeds in percent strings
_ANSI_RE = re.compile(r'\x1b\[[0-9;]*m')

def _clean_str(s: str) -> str:
    return _ANSI_RE.sub("", s).strip()


# ── Public API ────────────────────────────────────────────────────────────────

def fetch_info(url: str) -> str:
    """Return JSON with title, thumbnail, duration, uploader, is_playlist, entries."""
    opts = {
        "quiet": True, "no_warnings": True, "logger": _QuietLogger(),
        # FIX 10: 'in_playlist' gives full metadata for single videos;
        # True was returning a flat stub with no duration/thumbnail.
        "extract_flat": "in_playlist",
        "skip_download": True,
        "socket_timeout": 20, "retries": 3, "ignoreerrors": True,
    }
    try:
        with yt_dlp.YoutubeDL(opts) as ydl:
            info = ydl.extract_info(url, download=False)
        if info is None:
            return _json({"error": "No info returned — check the URL"})

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
        import traceback as _tb
        full = _tb.format_exc()
        return _json({"error": str(exc), "traceback": full[:1200]})


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
    # FIX 11: catch DownloadError specifically so bad URLs return [] not a crash
    except yt_dlp.utils.DownloadError:
        return "[]"
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
    Returns JSON: {"success": true, "file_path": "..."} or {"success": false, "error": "..."}

    FIX 12: All exception paths return valid JSON — nothing escapes to crash JNI.
    """
    try:
        os.makedirs(output_dir, exist_ok=True)
        tmp_dir = os.path.join(output_dir, ".tmp")
        os.makedirs(tmp_dir, exist_ok=True)
    except OSError as exc:
        return _json({"success": False, "error": f"Cannot create output dir: {exc}"})

    outtmpl = os.path.join(output_dir, "%(title)s.%(ext)s")

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

    last_file: dict[str, str] = {"path": ""}
    cb = _progress_callbacks.get(task_id)

    def progress_hook(d: dict) -> None:
        filename = d.get("filename", "") or last_file["path"]
        if filename:
            last_file["path"] = filename
        if d.get("status") == "downloading" and cb is not None:
            try:
                # FIX 13: strip ANSI codes and handle missing/malformed percent
                raw_pct = _clean_str(d.get("_percent_str") or "0").rstrip("%")
                try:
                    pct = float(raw_pct) if raw_pct else 0.0
                except ValueError:
                    pct = 0.0
                speed = _clean_str(d.get("_speed_str") or "--")
                eta   = _clean_str(d.get("_eta_str")   or "--")
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
        # FIX 12: truncated traceback prevents massive JNI string allocation
        tb = traceback.format_exc()
        return _json({"success": False, "error": f"{exc}\n{tb[:600]}"})


# ── Kotlin callback bridge ────────────────────────────────────────────────────
def _make_kotlin_hook(kotlin_cb):
    """
    Wrap a Kotlin/Java ProgressCallback as a Python callable.
    kotlin_cb must implement the Java interface ProgressCallback (not a Kotlin fun interface).
    """
    def hook(pct: float, speed: str, eta: str, filename: str) -> None:
        try:
            kotlin_cb.onProgress(pct, speed, eta, filename)
        except Exception:
            pass
    return hook
