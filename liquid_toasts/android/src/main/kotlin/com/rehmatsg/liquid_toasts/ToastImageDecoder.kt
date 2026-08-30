package com.rehmatsg.liquid_toasts

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * Off-main image decoding for the leading avatar — the Android analog of
 * `ToastImageDecoder.swift`. Sources meaningfully larger than the avatar slot
 * are downsampled to ~3× the 26dp slot (display headroom) so a photo-sized
 * payload never lives in memory at full resolution. Returns null for undecodable
 * bytes (the manager then collapses the reserved slot).
 */
internal object ToastImageDecoder {
    /** Only downsample when the source's larger dimension exceeds this (px). */
    private const val DOWNSAMPLE_THRESHOLD_PX = 256

    suspend fun decode(bytes: ByteArray, density: Float): Bitmap? = withContext(Dispatchers.Default) {
        // Bounds-only pass: read the source dimensions without allocating pixels.
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
        val srcMax = maxOf(bounds.outWidth, bounds.outHeight)
        if (srcMax <= 0) return@withContext null // undecodable

        if (srcMax <= DOWNSAMPLE_THRESHOLD_PX) {
            // Small source: plain decode.
            return@withContext BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
        }

        // Target ~3× the avatar slot in device pixels, mirroring the iOS Retina rule.
        val targetPx = (ToastMetrics.AVATAR_SIZE * 3 * density).toInt().coerceAtLeast(1)
        val opts = BitmapFactory.Options().apply {
            inSampleSize = computeSampleSize(srcMax, targetPx)
        }
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, opts)
    }

    /** Largest power-of-two sample size that keeps [srcMax] at or above [targetPx]. */
    private fun computeSampleSize(srcMax: Int, targetPx: Int): Int {
        var sample = 1
        while (srcMax / (sample * 2) >= targetPx) sample *= 2
        return sample
    }
}
