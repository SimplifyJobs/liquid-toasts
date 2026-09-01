package com.rehmatsg.liquid_toasts

import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.snap
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.waitForUpOrCancellation
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.width
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.PointerInputScope
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.input.pointer.positionChange
import androidx.compose.ui.input.pointer.util.VelocityTracker
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextMeasurer
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlin.math.abs
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

/**
 * A single toast — the Android analog of `ToastView.swift`. Orchestrates the row
 * content ([ToastContent]) on the frosted [ToastSurface], owning:
 *
 * - the measurement-driven **wrap/width** decision (via a [TextMeasurer], the
 *   analog of the two iOS off-screen probes): the message height at a fixed
 *   reference width past 1.5× a single line → multiline (pinned to a capped
 *   width); else the natural hugging width. Width changes animate on stackSpring.
 * - the **shape** morph: a pill (large radius) when single-line, a 22dp rounded
 *   rect when multiline (or the style override), animating the radius across the
 *   boundary.
 * - the interaction **gestures**: press-to-pause, tap, and drag-to-dismiss with
 *   rubber-banding, a commit threshold, and a velocity-predicted flick.
 *
 * `onFrame` reports the toast's size in px (the row content's origin is supplied
 * by the container via `onGloballyPositioned`).
 */
@Composable
internal fun ToastView(
    toast: ToastModel,
    deviceWidthDp: Float,
    isDark: Boolean,
    animationsEnabled: Boolean,
    onTapBody: () -> Unit,
    onAction: () -> Unit,
    onSwipe: () -> Unit,
    onPressStart: () -> Unit,
    onPressEnd: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val density = LocalDensity.current
    val view = LocalView.current
    val measurer = rememberTextMeasurer()

    val multilineWidthDp = ToastMetrics.multilineWidth(deviceWidthDp)

    // Wrap/width: recomputed only when a measurement-relevant input changes,
    // mirroring the iOS Equatable probe inputs. Roboto vs SF metrics may shift a
    // borderline wrap decision — acceptable; the *rule* (1.5× line height) ports.
    val measurement = remember(
        toast.message, toast.title, toast.maxLines,
        toast.action?.label, toast.showsLeadingSlot, deviceWidthDp,
    ) {
        measure(
            measurer = measurer,
            density = density.density,
            message = toast.message,
            title = toast.title,
            maxLines = toast.maxLines,
            hasAction = toast.action != null,
            actionLabel = toast.action?.label,
            showsLeading = toast.showsLeadingSlot,
            multilineWidthDp = multilineWidthDp,
        )
    }

    val isMultiline = measurement.multiline
    val targetWidthDp: Dp = if (isMultiline) multilineWidthDp.dp else measurement.naturalWidthDp.dp
    val animatedWidth by animateDpAsState(
        targetValue = targetWidthDp,
        animationSpec = if (animationsEnabled) ToastMetrics.stackSpringDp else snap(),
        label = "toastWidth",
    )

    // Shape is decided on the *total* text (title + message), not the message
    // alone: a capsule for a single line, a rounded rectangle for more than one
    // (a wrapped message, or a title above a message).
    val hasMultipleTextLines = isMultiline ||
        (!toast.title.isNullOrEmpty() && toast.message.isNotEmpty())
    val cornerRadius = toast.style?.cornerRadius?.toFloat()
        ?: if (hasMultipleTextLines) ToastMetrics.MULTILINE_CORNER_RADIUS else ToastMetrics.CAPSULE_CORNER_RADIUS

    // Drag offset (px), an Animatable so a cancelled drag springs back to rest.
    val dragOffset = remember { androidx.compose.animation.core.Animatable(0f) }
    // Animatable mutations are foreign suspend calls, so they can't run inside
    // the restricted AwaitPointerEventScope — the recognizer launches them here.
    val gestureScope = rememberCoroutineScope()

    Box(
        modifier
            .width(animatedWidth)
            .graphicsLayer { translationY = dragOffset.value }
            .semantics(mergeDescendants = true) { contentDescription = toast.accessibilityText }
            .pointerInput(toast.id) {
                // Press-to-pause: any touch-down pauses auto-dismiss; release /
                // cancel resumes. Non-consuming, so tap + drag still fire.
                awaitEachGesture {
                    awaitFirstDown(requireUnconsumed = false)
                    onPressStart()
                    try {
                        waitForUpOrCancellation()
                    } finally {
                        onPressEnd()
                    }
                }
            }
            .pointerInput(toast.id, animationsEnabled) {
                detectTapAndDrag(
                    density = density.density,
                    isBottom = toast.position.isBottom,
                    dragOffset = dragOffset,
                    scope = gestureScope,
                    animationsEnabled = animationsEnabled,
                    onTap = {
                        Haptics.impactLight(view)
                        onTapBody()
                    },
                    onDragStart = { Haptics.impactLight(view) },
                    onCommit = {
                        Haptics.impactMedium(view)
                        onSwipe()
                    },
                )
            },
    ) {
        ToastSurface(
            cornerRadiusDp = cornerRadius,
            isDark = isDark,
            modifier = Modifier.matchParentSize(),
            backgroundArgb = toast.style?.background?.resolve(isDark),
        )
        ToastContent(
            toast = toast,
            isMultiline = isMultiline,
            isDark = isDark,
            animationsEnabled = animationsEnabled,
            onAction = onAction,
        )
    }
}

/**
 * Combined tap + vertical drag recognizer. A drag activates past
 * [ToastMetrics.DRAG_MIN_DISTANCE]; dragging toward the nearest edge translates
 * 1:1, away rubber-bands at 0.35; the gesture commits at
 * [ToastMetrics.DRAG_COMMIT_DISTANCE] travel OR a velocity-predicted end past
 * [ToastMetrics.FLICK_DISTANCE]; otherwise it settles back on the settle spring.
 * A pointer that never activates a drag and lifts within slop is treated as a
 * tap.
 */
private suspend fun PointerInputScope.detectTapAndDrag(
    density: Float,
    isBottom: Boolean,
    dragOffset: androidx.compose.animation.core.Animatable<Float, *>,
    scope: CoroutineScope,
    animationsEnabled: Boolean,
    onTap: () -> Unit,
    onDragStart: () -> Unit,
    onCommit: () -> Unit,
) {
    val minPx = ToastMetrics.DRAG_MIN_DISTANCE * density
    val commitPx = ToastMetrics.DRAG_COMMIT_DISTANCE * density
    val flickPx = ToastMetrics.FLICK_DISTANCE * density
    val rubber = ToastMetrics.RUBBER_BAND_FACTOR

    awaitEachGesture {
        val down = awaitFirstDown(requireUnconsumed = false)
        val tracker = VelocityTracker()
        tracker.addPosition(down.uptimeMillis, down.position)
        var totalDy = 0f
        var dragging = false

        while (true) {
            val event = awaitPointerEvent()
            val change = event.changes.firstOrNull { it.id == down.id } ?: break
            if (!change.pressed) {
                if (dragging) {
                    val velocityY = tracker.calculateVelocity().y
                    // Project the flick: velocity (px/s) over a short horizon.
                    val predicted = totalDy + velocityY * 0.15f
                    val towardEdge = if (isBottom) totalDy > 0 else totalDy < 0
                    val flick = if (isBottom) predicted > flickPx else predicted < -flickPx
                    if (towardEdge && (abs(totalDy) > commitPx || flick)) {
                        onCommit()
                    } else if (animationsEnabled) {
                        scope.launch { dragOffset.animateTo(0f, animationSpec = ToastMetrics.settleSpring) }
                    } else {
                        scope.launch { dragOffset.snapTo(0f) }
                    }
                } else {
                    onTap()
                }
                break
            }
            val dy = change.positionChange().y
            totalDy += dy
            tracker.addPosition(change.uptimeMillis, change.position)
            if (!dragging && abs(totalDy) >= minPx) {
                dragging = true
                onDragStart()
            }
            if (dragging) {
                val towardEdge = if (isBottom) totalDy > 0 else totalDy < 0
                scope.launch { dragOffset.snapTo(if (towardEdge) totalDy else totalDy * rubber) }
                change.consume()
            }
        }
    }
}

// --- Measurement ---

private data class Measurement(val multiline: Boolean, val naturalWidthDp: Float)

/**
 * The wrap + hugging-width computation — the [TextMeasurer] analog of the two
 * iOS off-screen probes. All insets route through [ToastMetrics] so the
 * measurement stays in lockstep with the live row.
 */
private fun measure(
    measurer: TextMeasurer,
    density: Float,
    message: String,
    title: String?,
    maxLines: Int,
    hasAction: Boolean,
    actionLabel: String?,
    showsLeading: Boolean,
    multilineWidthDp: Float,
): Measurement {
    val messageStyle = TextStyle(fontSize = 15.sp, fontFamily = FontFamily.SansSerif)

    fun dpToPx(dp: Float) = dp * density
    fun pxToDp(px: Int) = px / density

    // Single-line height baseline for the wrap decision.
    val singleLine = measurer.measure("Ag", messageStyle, maxLines = 1)
    val lineHeightPx = singleLine.size.height.toFloat()

    // Multiline reference width (px): the space the message actually gets in the
    // multiline layout — subtract the insets, glyph slot, and action estimate.
    // Multiline hypothesis: the message wraps, so the row is always tall.
    val leading = ToastMetrics.leadingPadding(true, showsLeading, tallRow = true)
    val trailing = ToastMetrics.trailingPadding(true, hasAction)
    val spacing = ToastMetrics.rowSpacing(true)
    val glyph = if (showsLeading) ToastMetrics.ICON_SLOT + spacing else 0f
    val actionEstimateDp = if (hasAction) {
        val w = actionLabel?.let {
            pxToDp(measurer.measure(it, TextStyle(fontSize = 15.sp, fontFamily = FontFamily.SansSerif)).size.width) + 32f
        } ?: ToastMetrics.ACTION_WIDTH_ESTIMATE
        w + spacing
    } else {
        0f
    }
    val referenceDp = maxOf(
        ToastMetrics.PROBE_MIN_REFERENCE_WIDTH,
        multilineWidthDp - leading - trailing - glyph - actionEstimateDp,
    )
    val referencePx = dpToPx(referenceDp).toInt().coerceAtLeast(1)

    val messageAtReference = measurer.measure(
        text = message,
        style = messageStyle,
        maxLines = maxLines,
        constraints = Constraints(maxWidth = referencePx),
    )
    val multiline = messageAtReference.size.height > lineHeightPx * 1.5f

    // Natural hugging width (single-line row): insets + glyph slot + max(title,
    // message) single-line width + action, capped by the text column max.
    // Single-line hypothesis: tall when an action button or a title above the
    // message adds a second line.
    val leadS = ToastMetrics.leadingPadding(
        false,
        showsLeading,
        tallRow = hasAction || (!title.isNullOrEmpty() && message.isNotEmpty()),
    )
    val trailS = ToastMetrics.trailingPadding(false, hasAction)
    val spacingS = ToastMetrics.rowSpacing(false)
    val glyphS = if (showsLeading) ToastMetrics.ICON_SLOT + spacingS else 0f

    val singleStyle = messageStyle
    val titleStyle = TextStyle(fontSize = 15.sp, fontFamily = FontFamily.SansSerif, fontWeight = FontWeight.SemiBold)
    val msgW = pxToDp(measurer.measure(message, singleStyle, maxLines = 1).size.width)
    val titleW = title?.takeIf { it.isNotEmpty() }?.let {
        pxToDp(measurer.measure(it, titleStyle, maxLines = 1).size.width)
    } ?: 0f
    val textColW = maxOf(msgW, titleW).coerceAtMost(ToastMetrics.TEXT_COLUMN_MAX_WIDTH)
    val actionW = if (hasAction) actionEstimateDp else 0f

    val naturalWidthDp = leadS + glyphS + textColW + actionW + trailS

    return Measurement(multiline = multiline, naturalWidthDp = naturalWidthDp)
}
