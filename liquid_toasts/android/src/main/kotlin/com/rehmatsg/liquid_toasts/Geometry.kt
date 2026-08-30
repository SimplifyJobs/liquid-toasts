package com.rehmatsg.liquid_toasts

import android.app.Activity
import android.os.Build
import android.view.View

/**
 * Advisory geometry snapshot for the Dart `queryGeometry` call — the Android
 * analog of `DynamicIslandGeometry.geometrySnapshot`. Key names match the iOS
 * shape where they overlap (`hasDynamicIsland`, `cutoutType`, `safeArea`,
 * `screen`, `supportsDynamicIslandOrigin`, optional `exclusionRect`); Android has
 * no Dynamic Island, so those flags are always false, and `iosVersion` becomes
 * `androidVersion`. All lengths are in dp; `screen.scale` is the display density.
 */
internal object Geometry {
    fun snapshot(activity: Activity?): Map<String, Any?> {
        val decor: View? = activity?.window?.decorView
        val density = activity?.resources?.displayMetrics?.density ?: 1f

        // Safe-area insets (dp) from the root window insets: systemBars + cutout.
        var top = 0.0
        var left = 0.0
        var right = 0.0
        var bottom = 0.0
        var cutoutType = "none"
        var exclusionRect: Map<String, Any?>? = null

        if (decor != null && Build.VERSION.SDK_INT >= 30) {
            val insets = decor.rootWindowInsets
            if (insets != null) {
                val system = insets.getInsets(
                    android.view.WindowInsets.Type.systemBars() or
                        android.view.WindowInsets.Type.displayCutout(),
                )
                top = px(system.top, density)
                left = px(system.left, density)
                right = px(system.right, density)
                bottom = px(system.bottom, density)

                val cutout = insets.displayCutout
                if (cutout != null) {
                    cutoutType = "notch"
                    val rects = cutout.boundingRects
                    if (rects.isNotEmpty()) {
                        val r = rects[0]
                        exclusionRect = mapOf(
                            "x" to px(r.left, density),
                            "y" to px(r.top, density),
                            "width" to px(r.width(), density),
                            "height" to px(r.height(), density),
                        )
                    }
                }
            }
        } else if (decor != null && Build.VERSION.SDK_INT >= 28) {
            @Suppress("DEPRECATION")
            val insets = decor.rootWindowInsets
            if (insets != null) {
                @Suppress("DEPRECATION")
                top = px(insets.systemWindowInsetTop, density)
                @Suppress("DEPRECATION")
                left = px(insets.systemWindowInsetLeft, density)
                @Suppress("DEPRECATION")
                right = px(insets.systemWindowInsetRight, density)
                @Suppress("DEPRECATION")
                bottom = px(insets.systemWindowInsetBottom, density)
                if (insets.displayCutout != null) cutoutType = "notch"
            }
        }

        val metrics = activity?.resources?.displayMetrics
        val screenWidthDp = if (metrics != null) metrics.widthPixels / density else 0f
        val screenHeightDp = if (metrics != null) metrics.heightPixels / density else 0f

        return mapOf(
            "hasDynamicIsland" to false,
            "supportsDynamicIslandOrigin" to false,
            "cutoutType" to cutoutType,
            "safeArea" to mapOf(
                "top" to top,
                "left" to left,
                "right" to right,
                "bottom" to bottom,
            ),
            "screen" to mapOf(
                "width" to screenWidthDp.toDouble(),
                "height" to screenHeightDp.toDouble(),
                "scale" to density.toDouble(),
            ),
            "androidVersion" to Build.VERSION.RELEASE,
        ).let { base ->
            if (exclusionRect != null) base + ("exclusionRect" to exclusionRect) else base
        }
    }

    private fun px(value: Int, density: Float): Double =
        if (density > 0f) value / density.toDouble() else value.toDouble()
}
