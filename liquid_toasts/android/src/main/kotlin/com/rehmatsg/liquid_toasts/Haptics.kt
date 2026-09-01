package com.rehmatsg.liquid_toasts

import android.os.Build
import android.view.HapticFeedbackConstants
import android.view.View

/**
 * Maps toast + gesture haptics to [HapticFeedbackConstants], performed on a
 * provided [View] via `performHapticFeedback` (no permission, respects the
 * system haptics setting). The Android analog of `Haptics.swift`, fired at the
 * same sites as iOS. `CONFIRM`/`REJECT` are API 30+, with pre-30 fallbacks.
 */
internal object Haptics {
    /** Semantic toast haptic (fired on appear). [ToastHapticKind.None] is a no-op. */
    fun perform(view: View, kind: ToastHapticKind) {
        val constant = when (kind) {
            ToastHapticKind.None -> return
            ToastHapticKind.Success ->
                if (Build.VERSION.SDK_INT >= 30) HapticFeedbackConstants.CONFIRM
                else HapticFeedbackConstants.VIRTUAL_KEY
            ToastHapticKind.Error ->
                if (Build.VERSION.SDK_INT >= 30) HapticFeedbackConstants.REJECT
                else HapticFeedbackConstants.LONG_PRESS
            ToastHapticKind.Warning -> HapticFeedbackConstants.LONG_PRESS
            ToastHapticKind.Selection -> HapticFeedbackConstants.CLOCK_TICK
        }
        view.performHapticFeedback(constant)
    }

    /** Light gesture impact (drag start, body tap, action press-down). */
    fun impactLight(view: View) {
        view.performHapticFeedback(HapticFeedbackConstants.VIRTUAL_KEY)
    }

    /** Medium gesture impact (drag commit). */
    fun impactMedium(view: View) {
        view.performHapticFeedback(HapticFeedbackConstants.CONTEXT_CLICK)
    }
}
