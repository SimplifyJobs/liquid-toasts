package com.rehmatsg.liquid_toasts

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.keyframes
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.VectorPainter
import androidx.compose.ui.graphics.vector.rememberVectorPainter
import androidx.compose.ui.unit.dp

/**
 * The leading glyph — the Android analog of `IconView.swift`. Renders a rotating
 * spinner while [ToastModel.state] is loading, otherwise a resolved Material
 * glyph (SF Symbol name → [SymbolMap]) that crossfades on the loading↔static
 * morph and (optionally) plays a [ToastSymbolEffect].
 *
 * The symbol resolution mirrors iOS `IconView.validatedSymbol`: explicit icon →
 * its mapped vector; unmapped → the semantic default; neither → nothing (the
 * slot then collapses, handled by the caller checking [ToastModel.showsIcon]).
 *
 * All effects and the spinner rotation are gated on [animationsEnabled] — the
 * Reduce-Motion analog freezes them (matching iOS's disabled-animations path).
 */
@Composable
internal fun IconView(
    toast: ToastModel,
    isDark: Boolean,
    animationsEnabled: Boolean,
    modifier: Modifier = Modifier,
) {
    val tint = iconTint(toast, isDark)
    val loading = toast.state == ToastContentState.Loading
    val vector = if (loading) null else resolveVector(toast)

    Box(
        modifier.size(ToastMetrics.ICON_SLOT.dp),
        contentAlignment = Alignment.Center,
    ) {
        if (loading) {
            Spinner(color = tint, animationsEnabled = animationsEnabled)
        } else if (vector != null) {
            SymbolGlyph(
                vector = vector,
                tint = tint,
                effect = toast.style?.symbolEffect ?: ToastSymbolEffect.None,
                animationsEnabled = animationsEnabled,
            )
        }
    }
}

/** Icon-color override → tint override → semantic tint (neutral when semantic is none). */
private fun iconTint(toast: ToastModel, isDark: Boolean): Color {
    toast.style?.iconColor?.let { return Color(it.resolve(isDark)) }
    toast.style?.tint?.let { return Color(it.resolve(isDark)) }
    toast.semantic.tint?.let { return Color(it.resolve(isDark)) }
    return if (isDark) Color.White else Color.Black
}

/** Resolves the explicit icon or the semantic default via [SymbolMap]. */
private fun resolveVector(toast: ToastModel): ImageVector? =
    SymbolMap.resolve(toast.resolvedSymbol) ?: SymbolMap.semanticDefault(toast.semantic.wire)

/** A 17dp SF-Symbol-equivalent glyph with the requested looping / one-shot effect. */
@Composable
private fun SymbolGlyph(
    vector: ImageVector,
    tint: Color,
    effect: ToastSymbolEffect,
    animationsEnabled: Boolean,
) {
    val painter: VectorPainter = rememberVectorPainter(vector)
    val infinite = rememberInfiniteTransition(label = "symbolEffect")

    // Looping effect drivers (each no-op when animations are disabled).
    val pulseAlpha by if (animationsEnabled && (effect == ToastSymbolEffect.Pulse || effect == ToastSymbolEffect.VariableColor)) {
        infinite.animateFloat(
            initialValue = 1f, targetValue = 0.55f,
            animationSpec = infiniteRepeatable(tween(900), RepeatMode.Reverse), label = "pulse",
        )
    } else remember { mutableFloatStateOf(1f) }

    val breatheScale by if (animationsEnabled && effect == ToastSymbolEffect.Breathe) {
        infinite.animateFloat(
            initialValue = 1f, targetValue = 1.06f,
            animationSpec = infiniteRepeatable(tween(1200), RepeatMode.Reverse), label = "breathe",
        )
    } else remember { mutableFloatStateOf(1f) }

    val wiggleDeg by if (animationsEnabled && effect == ToastSymbolEffect.Wiggle) {
        infinite.animateFloat(
            initialValue = -8f, targetValue = 8f,
            animationSpec = infiniteRepeatable(tween(500), RepeatMode.Reverse), label = "wiggle",
        )
    } else remember { mutableFloatStateOf(0f) }

    val rotateDeg by if (animationsEnabled && effect == ToastSymbolEffect.Rotate) {
        infinite.animateFloat(
            initialValue = 0f, targetValue = 360f,
            animationSpec = infiniteRepeatable(tween(1400, easing = LinearEasing), RepeatMode.Restart), label = "rotate",
        )
    } else remember { mutableFloatStateOf(0f) }

    // One-shot appear drivers (bounce / drawOn).
    var appearScale by remember { mutableFloatStateOf(if (effect == ToastSymbolEffect.Bounce) 1f else 1f) }
    var drawProgress by remember {
        mutableFloatStateOf(if (effect == ToastSymbolEffect.DrawOn && animationsEnabled) 0f else 1f)
    }
    LaunchedEffect(effect, animationsEnabled) {
        if (!animationsEnabled) {
            appearScale = 1f; drawProgress = 1f; return@LaunchedEffect
        }
        when (effect) {
            ToastSymbolEffect.Bounce -> {
                val anim = androidx.compose.animation.core.Animatable(1f)
                anim.animateTo(
                    1f,
                    animationSpec = keyframes {
                        durationMillis = 420
                        1f at 0
                        1.18f at 180
                        1f at 420
                    },
                ) { appearScale = value }
            }
            ToastSymbolEffect.DrawOn -> {
                val anim = androidx.compose.animation.core.Animatable(0f)
                anim.animateTo(1f, animationSpec = tween(360)) { drawProgress = value }
            }
            else -> Unit
        }
    }

    val effectScale = breatheScale * appearScale * (0.6f + 0.4f * drawProgress)
    val effectAlpha = pulseAlpha * drawProgress
    val effectRotation = wiggleDeg + rotateDeg

    val colorFilter = androidx.compose.ui.graphics.ColorFilter.tint(tint)
    Canvas(Modifier.size(17.dp)) {
        rotate(effectRotation) {
            scale(effectScale) {
                // The glyph vectors are authored on a 24x24 viewport; scale to fit
                // the 17dp slot and tint the black path data at draw time.
                val vf = size.minDimension / 24f
                val dx = (size.width - 24f * vf) / 2f
                val dy = (size.height - 24f * vf) / 2f
                translate(dx, dy) {
                    scale(vf, vf, pivot = Offset.Zero) {
                        with(painter) {
                            draw(Size(24f, 24f), alpha = effectAlpha, colorFilter = colorFilter)
                        }
                    }
                }
            }
        }
    }
}

/** Fixed-size spinner used in the leading slot. */
@Composable
private fun Spinner(color: Color, animationsEnabled: Boolean) {
    SpinnerArc(color = color, animationsEnabled = animationsEnabled)
}

/**
 * Indeterminate spinner — a trimmed circle arc (~0.72 of the circle) rotating
 * once every 0.85s, 17dp, stroke 2.4dp. Mirrors iOS `SpinnerView`. Shared by the
 * leading slot and the action button's busy state.
 */
@Composable
internal fun SpinnerArc(color: Color, animationsEnabled: Boolean) {
    val rotation = if (animationsEnabled) {
        val infinite = rememberInfiniteTransition(label = "spinner")
        val r by infinite.animateFloat(
            initialValue = 0f, targetValue = 360f,
            animationSpec = infiniteRepeatable(tween(850, easing = LinearEasing), RepeatMode.Restart),
            label = "spin",
        )
        r
    } else {
        0f
    }
    Canvas(Modifier.size(17.dp)) {
        val strokePx = 2.4.dp.toPx()
        val inset = strokePx / 2f
        rotate(rotation) {
            drawArc(
                brush = SolidColor(color.copy(alpha = 0.85f)),
                startAngle = 0f,
                sweepAngle = 0.72f * 360f,
                useCenter = false,
                topLeft = Offset(inset, inset),
                size = Size(size.width - strokePx, size.height - strokePx),
                style = Stroke(width = strokePx, cap = androidx.compose.ui.graphics.StrokeCap.Round),
            )
        }
    }
}
