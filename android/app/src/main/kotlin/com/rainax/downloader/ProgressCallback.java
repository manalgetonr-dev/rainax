package com.rainax.downloader;

/**
 * Java interface proxy for Chaquopy (CPython → JNI).
 * Kotlin fun interfaces are NOT proxiable by Chaquopy — must be a real Java interface.
 */
public interface ProgressCallback {
    void onProgress(float pct, String speed, String eta, String filename);
}
