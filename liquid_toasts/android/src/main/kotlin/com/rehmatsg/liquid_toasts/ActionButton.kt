package com.rehmatsg.liquid_toasts

import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * The single, fully-rounded action button — the Android analog of
 * `ActionButton.swift`. Background is the role color (or explicit override) at
 * alpha 0.24 dark / 0.15 light; the label is that color at full opacity. On
 * press-down it shrinks to 0.92 (spring) and fires a light haptic. While busy
 * ([isLoading]), the label is swapped for a spinner **keeping the measured
 * width** (the label stays laid out but transparent), and taps are ignored.
 */
@Composable
internal fun ActionButton(
    action: ToastActionModel,
    isLoading: Boolean,
    isDark: Boolean,
    animationsEnabled: Boolean,
    onTap: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val view = LocalView.current
    val color = Color((action.color ?: action.role.color).resolve(isDark))
    val bg = color.copy(alpha = if (isDark) 0.24f else 0.15f)

    var pressed by remember { mutableStateOf(false) }
    val scale by animateFloatAsState(
        targetValue = if (pressed && animationsEnabled) 0.92f else 1f,
        animationSpec = spring(dampingRatio = 0.6f, stiffness = Spring.StiffnessMedium),
        label = "actionPress",
    )

    Box(
        modifier
            .graphicsLayer { scaleX = scale; scaleY = scale }
            .background(bg, CircleShape)
            .pointerInput(action.actionId, isLoading) {
                if (isLoading) return@pointerInput
                detectTapGestures(
                    onPress = {
                        pressed = true
                        Haptics.impactLight(view)
                        tryAwaitRelease()
                        pressed = false
                    },
                    onTap = { onTap() },
                )
            }
            .padding(horizontal = 16.dp, vertical = 9.dp),
        contentAlignment = Alignment.Center,
    ) {
        // The label always occupies its intrinsic width so the button doesn't
        // reflow when it flips to the spinner; it just goes transparent.
        BasicText(
            text = action.label,
            modifier = Modifier.alpha(if (isLoading) 0f else 1f),
            style = TextStyle(
                color = color,
                fontSize = 15.sp,
                fontWeight = FontWeight.SemiBold,
                fontFamily = FontFamily.SansSerif,
            ),
            maxLines = 1,
        )
        if (isLoading) {
            SpinnerArc(color = color, animationsEnabled = animationsEnabled)
        }
    }
}
