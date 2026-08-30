package com.rehmatsg.liquid_toasts

import android.graphics.RectF
import android.os.Build
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.tween
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.boundsInWindow
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import kotlin.math.PI
import kotlin.math.sin

/** Window-space safe-area insets (dp), fed by the overlay host's inset listener. */
internal data class ToastInsets(
    val top: Dp = 0.dp,
    val left: Dp = 0.dp,
    val right: Dp = 0.dp,
    val bottom: Dp = 0.dp,
    /** Extra bottom inset from the IME (keyboard), so bottom toasts ride above it. */
    val ime: Dp = 0.dp,
)

/**
 * Root composable hosted in the overlay — the Android analog of
 * `ToastContainerView.swift`. Reads [ToastManager.toasts] (the single Compose
 * input), groups by position, and lays each of the 7 positions out as an
 * independent vertical list at its corner/edge of a full-size [Box].
 *
 * Ordering mirrors iOS exactly: bottom positions render as-is (newest last, at
 * the bottom edge); top positions render reversed (newest first, nearest the
 * top edge). Per-row `key(id)` + the immutable [ToastModel] give the iOS
 * `.equatable()` row isolation — a change to one toast recomposes only its row.
 *
 * Entrance, exit, and reflow all spring on the stack spring (or degrade to a
 * 200ms fade / instant when animations are disabled — the Reduce-Motion analog).
 * Dismissed toasts are briefly retained locally so their exit (scale→0.86 +
 * fade, plus a blur on API 31+) can play before they drop.
 */
@Composable
internal fun ToastContainer(
    manager: ToastManager,
    insets: ToastInsets,
    customSafeArea: ToastSafeArea,
    entranceDistanceDp: Float,
    isDark: Boolean,
    animationsEnabled: Boolean,
    deviceWidthDp: Float,
) {
    val toasts by manager.toasts

    // Group by position, preserving insertion order (each position an independent
    // list so a bottom toast never disturbs the top list).
    val groups = remember(toasts) {
        val order = ArrayList<ToastPositionModel>()
        val map = HashMap<ToastPositionModel, MutableList<ToastModel>>()
        for (t in toasts) {
            if (map[t.position] == null) order.add(t.position)
            map.getOrPut(t.position) { ArrayList() }.add(t)
        }
        order.map { it to map.getValue(it) }
    }

    Box(Modifier.fillMaxSize()) {
        for ((position, list) in groups) {
            PositionedList(
                position = position,
                toasts = if (position.isBottom) list else list.asReversed(),
                insets = insets,
                customSafeArea = customSafeArea,
                entranceDistanceDp = maxOf(entranceDistanceDp, customSafeArea.top * 0.5f),
                isDark = isDark,
                animationsEnabled = animationsEnabled,
                deviceWidthDp = deviceWidthDp,
                manager = manager,
            )
        }
    }
}

@Composable
private fun PositionedList(
    position: ToastPositionModel,
    toasts: List<ToastModel>,
    insets: ToastInsets,
    customSafeArea: ToastSafeArea,
    entranceDistanceDp: Float,
    isDark: Boolean,
    animationsEnabled: Boolean,
    deviceWidthDp: Float,
    manager: ToastManager,
) {
    val alignment = alignmentFor(position)
    // The custom values are minimum screen-edge insets, so take the larger of
    // each app-provided edge and the device safe area. Bottom positions compare
    // against the IME-safe bottom as well.
    val padding = PaddingValues(
        start = maxOf(insets.left.value, customSafeArea.left).dp + 12.dp,
        end = maxOf(insets.right.value, customSafeArea.right).dp + 12.dp,
        top = maxOf(insets.top.value, customSafeArea.top).dp + 8.dp,
        bottom = maxOf(
            insets.bottom.value + if (position.isBottom) insets.ime.value else 0f,
            customSafeArea.bottom,
        ).dp + 8.dp,
    )

    // Retention: a dismissed toast is kept in the list (as a snapshot) with its
    // id marked `exiting` so its exit transition plays in place; it drops once
    // the animation finishes. The last-seen snapshot per id lets the row keep
    // rendering after the manager has removed it.
    // Keyed by `rowKey`, not `id`: a group re-show with unchanged text keeps the
    // same rowKey while swapping the wire id, so the row shakes in place instead
    // of exit+entering (frames are still tracked per wire id inside the row).
    val snapshots = remember { mutableStateMapOf<String, ToastModel>() }
    val exiting = remember { mutableStateMapOf<String, Boolean>() }

    val liveKeys = toasts.map { it.rowKey }.toSet()
    for (t in toasts) {
        snapshots[t.rowKey] = t
        exiting.remove(t.rowKey)
    }
    // Mark anything we still hold but the manager dropped as exiting.
    for (rowKey in snapshots.keys.toList()) {
        if (rowKey !in liveKeys && exiting[rowKey] == null) exiting[rowKey] = true
    }

    // Display order: live toasts (in their list order) followed by exiting
    // snapshots interleaved at their last index is over-engineered; keeping
    // exiting rows appended in key order is visually fine because siblings reflow
    // on the stack spring regardless.
    val displayed = buildList {
        addAll(toasts)
        for (rowKey in snapshots.keys) {
            if (rowKey !in liveKeys) snapshots[rowKey]?.let { add(it) }
        }
    }

    Box(
        Modifier
            .fillMaxSize()
            .padding(padding),
        contentAlignment = alignment,
    ) {
        Column(
            horizontalAlignment = columnAlignmentFor(position),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            for (toast in displayed) {
                key(toast.rowKey) {
                    ToastRow(
                        toast = toast,
                        position = position,
                        exiting = exiting[toast.rowKey] == true,
                        entranceDistanceDp = entranceDistanceDp,
                        isDark = isDark,
                        animationsEnabled = animationsEnabled,
                        deviceWidthDp = deviceWidthDp,
                        manager = manager,
                        onExited = {
                            snapshots.remove(toast.rowKey)
                            exiting.remove(toast.rowKey)
                        },
                    )
                }
            }
        }
    }
}

/**
 * One toast row. Drives:
 *  - **entrance** (offset from ±entranceDistance + scale 0.9→1 + fade 0→1,
 *    launched after first composition so even the first toast animates; skipped
 *    when [ToastModel.hasEntered] — a config-change reinstall);
 *  - **exit** ([exiting] → scale 1→0.86 + fade→0, plus a 9dp blur on API 31+),
 *    calling [onExited] when done so the container drops the retained snapshot;
 *  - **frame reporting** into [ToastManager.frames] for pass-through hit-testing.
 *
 * With animations disabled the entrance is instant and the exit is a 200ms fade
 * (the Reduce-Motion analog).
 */
@Composable
private fun ToastRow(
    toast: ToastModel,
    position: ToastPositionModel,
    exiting: Boolean,
    entranceDistanceDp: Float,
    isDark: Boolean,
    animationsEnabled: Boolean,
    deviceWidthDp: Float,
    manager: ToastManager,
    onExited: () -> Unit,
) {
    val enter = remember { Animatable(if (toast.hasEntered || !animationsEnabled) 1f else 0f) }
    // Exit progress 1→0 (1 = present, 0 = gone).
    val exit = remember { Animatable(1f) }
    // Shake progress 0→1, replayed each time [ToastModel.shakeToken] bumps (a
    // group re-show with unchanged text). Rest sits at 0 (no displacement).
    val shake = remember { Animatable(0f) }

    LaunchedEffect(toast.shakeToken) {
        if (toast.shakeToken == 0 || !animationsEnabled) return@LaunchedEffect
        shake.snapTo(0f)
        shake.animateTo(1f, animationSpec = tween(ToastMetrics.SHAKE_DURATION_MS, easing = LinearEasing))
        shake.snapTo(0f)
    }

    LaunchedEffect(toast.id) {
        if (toast.hasEntered) {
            enter.snapTo(1f)
            return@LaunchedEffect
        }
        manager.markEntered(toast.id)
        if (!animationsEnabled) enter.snapTo(1f)
        else {
            enter.snapTo(0f)
            enter.animateTo(1f, animationSpec = ToastMetrics.stackSpring)
        }
    }

    LaunchedEffect(exiting) {
        if (!exiting) return@LaunchedEffect
        if (animationsEnabled) {
            exit.animateTo(0f, animationSpec = ToastMetrics.stackSpring)
        } else {
            exit.animateTo(0f, animationSpec = tween(ToastMetrics.REDUCED_MOTION_DURATION_MS))
        }
        onExited()
    }

    val enterP = enter.value
    val exitP = exit.value
    val sign = if (position.isTop) -1f else 1f
    val translationYDp = (1f - enterP) * entranceDistanceDp * sign
    // Horizontal shake: oscillates SHAKE_COUNT times over one unit with a linear
    // amplitude falloff, settling at 0.
    val shakeP = shake.value
    val shakeDx = if (shakeP > 0f && shakeP < 1f) {
        ToastMetrics.SHAKE_AMPLITUDE * (1f - shakeP) * sin(shakeP * 2f * PI.toFloat() * ToastMetrics.SHAKE_COUNT)
    } else {
        0f
    }
    // Enter scales 0.9→1; exit scales 1→0.86.
    val scale = (0.9f + 0.1f * enterP) * (0.86f + 0.14f * exitP)
    val alpha = enterP * exitP
    val exitBlur = ((1f - exitP) * 9f).dp

    ToastView(
        toast = toast,
        deviceWidthDp = deviceWidthDp,
        isDark = isDark,
        animationsEnabled = animationsEnabled,
        onTapBody = { manager.handleBodyTap(toast.id) },
        onAction = { manager.handleActionTap(toast.id) },
        onSwipe = { manager.handleSwipe(toast.id) },
        onPressStart = { manager.pauseAutoDismiss(toast.id) },
        onPressEnd = { manager.resumeAutoDismiss(toast.id) },
        modifier = Modifier
            .graphicsLayer {
                translationX += shakeDx * density
                translationY += translationYDp * density
                scaleX = scale
                scaleY = scale
            }
            .alpha(alpha)
            .let { if (Build.VERSION.SDK_INT >= 31 && exitP < 1f) it.blur(exitBlur) else it }
            .onGloballyPositioned { coords ->
                if (exiting) return@onGloballyPositioned
                val b = coords.boundsInWindow()
                manager.frames[toast.id] = RectF(b.left, b.top, b.right, b.bottom)
            },
    )
}

private fun alignmentFor(position: ToastPositionModel): Alignment = when (position) {
    ToastPositionModel.TopCenter -> Alignment.TopCenter
    ToastPositionModel.TopLeading -> Alignment.TopStart
    ToastPositionModel.TopTrailing -> Alignment.TopEnd
    ToastPositionModel.Center -> Alignment.Center
    ToastPositionModel.BottomCenter -> Alignment.BottomCenter
    ToastPositionModel.BottomLeading -> Alignment.BottomStart
    ToastPositionModel.BottomTrailing -> Alignment.BottomEnd
}

private fun columnAlignmentFor(position: ToastPositionModel): Alignment.Horizontal =
    when (position.horizontalBias) {
        -1 -> Alignment.Start
        1 -> Alignment.End
        else -> Alignment.CenterHorizontally
    }
