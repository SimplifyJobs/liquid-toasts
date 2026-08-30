package com.rehmatsg.liquid_toasts

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.foundation.layout.height
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.painter.BitmapPainter
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * The toast's row content — the Android analog of `ToastContentView.swift`:
 * leading slot (avatar / image → circular progress ring → spinner → icon), the
 * text column (title, message, optional linear progress), and the optional
 * trailing action button, with the insets for the current (single-line vs
 * multiline) treatment.
 */
@Composable
internal fun ToastContent(
    toast: ToastModel,
    isMultiline: Boolean,
    isDark: Boolean,
    animationsEnabled: Boolean,
    onAction: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val foreground = toast.style?.foreground?.let { Color(it.resolve(isDark)) }
        ?: if (isDark) Color.White else Color.Black
    val accent = accentTint(toast, isDark)

    // Centered text on a compact, text-only toast: no leading glyph, no action,
    // not the full-width multiline layout.
    val centerText = !toast.showsLeadingSlot && toast.action == null && !isMultiline

    Row(
        modifier
            .padding(
                start = ToastMetrics.leadingPadding(
                    isMultiline,
                    toast.showsLeadingSlot,
                    tallRow = isMultiline || toast.action != null ||
                        (!toast.title.isNullOrEmpty() && toast.message.isNotEmpty()),
                ).dp,
                end = ToastMetrics.trailingPadding(isMultiline, toast.action != null).dp,
                top = ToastMetrics.verticalPadding(isMultiline).dp,
                bottom = ToastMetrics.verticalPadding(isMultiline).dp,
            ),
        horizontalArrangement = Arrangement.spacedBy(ToastMetrics.rowSpacing(isMultiline).dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        // --- Leading slot (priority: avatar/image → ring → spinner → icon) ---
        if (toast.expectsImage || toast.image != null) {
            AvatarSlot(toast.image)
        } else if (toast.showsCircularProgress) {
            CircularProgressRing(value = toast.progress ?: 0.0, tint = accent)
        } else if (toast.showsIcon) {
            IconView(toast = toast, isDark = isDark, animationsEnabled = animationsEnabled)
        }

        // --- Text column ---
        val columnModifier = if (isMultiline) {
            Modifier.weight(1f, fill = true)
        } else {
            Modifier.widthIn(max = ToastMetrics.TEXT_COLUMN_MAX_WIDTH.dp)
        }
        androidx.compose.foundation.layout.Column(
            columnModifier,
            horizontalAlignment = if (centerText) Alignment.CenterHorizontally else Alignment.Start,
            verticalArrangement = Arrangement.spacedBy(2.dp),
        ) {
            val align = if (centerText) TextAlign.Center else TextAlign.Start
            toast.title?.takeIf { it.isNotEmpty() }?.let { title ->
                BasicText(
                    text = title,
                    style = TextStyle(
                        color = foreground,
                        fontSize = 15.sp,
                        fontWeight = FontWeight.SemiBold,
                        fontFamily = FontFamily.SansSerif,
                        textAlign = align,
                    ),
                    maxLines = toast.titleMaxLines,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            if (toast.message.isNotEmpty()) {
                BasicText(
                    text = toast.message,
                    style = TextStyle(
                        color = if (toast.title == null) foreground else foreground.copy(alpha = 0.85f),
                        fontSize = 15.sp,
                        fontFamily = FontFamily.SansSerif,
                        textAlign = align,
                    ),
                    maxLines = toast.maxLines,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            toast.progress?.takeIf { toast.progressStyle == ToastProgressStyle.Linear }?.let { p ->
                LinearProgressBar(
                    value = p.coerceIn(0.0, 1.0),
                    tint = accent,
                    fullWidth = isMultiline,
                    modifier = Modifier.padding(top = 4.dp),
                )
            }
        }

        // --- Trailing action ---
        toast.action?.let { action ->
            ActionButton(
                action = action,
                isLoading = toast.isActionBusy,
                isDark = isDark,
                animationsEnabled = animationsEnabled,
                onTap = onAction,
            )
        }
    }
}

/** Accent for progress: icon-color → tint → semantic tint (accent blue for none). */
private fun accentTint(toast: ToastModel, isDark: Boolean): Color {
    toast.style?.iconColor?.let { return Color(it.resolve(isDark)) }
    toast.style?.tint?.let { return Color(it.resolve(isDark)) }
    toast.semantic.tint?.let { return Color(it.resolve(isDark)) }
    return Color(if (isDark) 0xFF0A84FF.toInt() else 0xFF007AFF.toInt())
}

/**
 * Reserves the avatar footprint from the first frame (so the row never shifts
 * when the pixels land) — a 26dp circle with a 0.5dp white 0.15 stroke.
 */
@Composable
private fun AvatarSlot(image: ToastImage?) {
    val bitmap = image?.pixels as? android.graphics.Bitmap
    Box(
        Modifier
            .size(ToastMetrics.AVATAR_SIZE.dp)
            .clip(CircleShape),
        contentAlignment = Alignment.Center,
    ) {
        if (bitmap != null) {
            androidx.compose.foundation.Image(
                painter = BitmapPainter(bitmap.asImageBitmap()),
                contentDescription = null,
                contentScale = ContentScale.Crop,
                modifier = Modifier.size(ToastMetrics.AVATAR_SIZE.dp),
            )
        }
        Canvas(Modifier.size(ToastMetrics.AVATAR_SIZE.dp)) {
            val strokePx = 0.5.dp.toPx()
            drawCircle(
                color = Color.White.copy(alpha = 0.15f),
                radius = (size.minDimension - strokePx) / 2f,
                style = Stroke(width = strokePx),
            )
        }
    }
}

/**
 * A determinate circular progress ring sized to the leading icon slot: a track
 * at 0.22 alpha and a rounded arc, drawn directly (an upload/download
 * indicator). Mirrors iOS `CircularProgressView`.
 */
@Composable
private fun CircularProgressRing(value: Double, tint: Color) {
    val clamped = value.coerceIn(0.0, 1.0).toFloat()
    val animated by animateFloatAsState(clamped, animationSpec = tween(250), label = "ring")
    Canvas(Modifier.size(ToastMetrics.PROGRESS_RING_SIZE.dp)) {
        val strokePx = 2.6.dp.toPx()
        val inset = strokePx / 2f
        val arcSize = Size(size.width - strokePx, size.height - strokePx)
        val topLeft = Offset(inset, inset)
        drawArc(
            color = tint.copy(alpha = 0.22f),
            startAngle = 0f, sweepAngle = 360f, useCenter = false,
            topLeft = topLeft, size = arcSize,
            style = Stroke(width = strokePx),
        )
        drawArc(
            color = tint,
            startAngle = -90f, sweepAngle = animated * 360f, useCenter = false,
            topLeft = topLeft, size = arcSize,
            style = Stroke(width = strokePx, cap = StrokeCap.Round),
        )
    }
}

/**
 * A capsule linear progress bar: fixed 160dp on a hugging capsule, full width
 * when multiline. Mirrors iOS `ProgressView(.linear)`.
 */
@Composable
private fun LinearProgressBar(value: Double, tint: Color, fullWidth: Boolean, modifier: Modifier) {
    val clamped = value.coerceIn(0.0, 1.0).toFloat()
    val animated by animateFloatAsState(clamped, animationSpec = tween(250), label = "linear")
    val widthModifier = if (fullWidth) Modifier.fillMaxWidth() else Modifier.width(ToastMetrics.LINEAR_PROGRESS_WIDTH.dp)
    Canvas(modifier.then(widthModifier).height(4.dp)) {
        val h = size.height
        val r = CornerRadius(h / 2f, h / 2f)
        drawRoundRect(color = tint.copy(alpha = 0.22f), size = size, cornerRadius = r)
        drawRoundRect(
            color = tint,
            size = Size(size.width * animated, h),
            cornerRadius = r,
        )
    }
}
