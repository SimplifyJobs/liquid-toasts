package com.rehmatsg.liquid_toasts

import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.spring
import androidx.compose.ui.unit.Dp

/**
 * Single source for every shared layout constant and spring in the toast render
 * tree — the Android analog of `ToastMetrics.swift`, ported 1pt → 1dp. The
 * off-screen measurement probes must mirror the live layout's insets exactly, so
 * the inset FUNCTIONS (not just the numbers) are ported: change layout numbers
 * HERE and both the live row and the probes move in lockstep.
 *
 * Values are plain `Float` dp magnitudes (wrap with `.dp` at the call site) so
 * this object stays free of a `Density`/`Dp` dependency and unit-tests on the JVM.
 */
internal object ToastMetrics {
    // --- Row insets (multiline gets roomier insets than the hugging capsule) ---

    private fun baseHorizontalPadding(multiline: Boolean): Float = if (multiline) 18f else 16f

    fun verticalPadding(multiline: Boolean): Float = if (multiline) 14f else 11f

    /** Roomier leading inset for a tall row so a vertically-centered glyph reads
     *  symmetric with the top/bottom gap instead of hugging the left edge. */
    const val TALL_ROW_LEADING_PADDING: Float = 20f

    /**
     * Leading inset for the icon/avatar slot. A plain single-line toast pins the
     * glyph snugly (matching the vertical inset). But when the row is *tall* —
     * more than one content line — the centered glyph would sit closer to the
     * left edge than to the top/bottom, so it gets a roomier inset. A row is tall
     * when [tallRow] is set: a multiline (wrapped) message, a title above a
     * message (two lines), or an action button (taller than the glyph). The
     * caller computes it so the live view and the measurement pass agree.
     */
    fun leadingPadding(multiline: Boolean, hasLeadingSlot: Boolean, tallRow: Boolean): Float =
        if (!hasLeadingSlot) baseHorizontalPadding(multiline)
        else if (tallRow) TALL_ROW_LEADING_PADDING
        else verticalPadding(multiline)

    /**
     * Trailing inset. With an action present it matches the tighter button margin
     * (11); otherwise it mirrors the base horizontal inset.
     */
    fun trailingPadding(multiline: Boolean, hasAction: Boolean): Float =
        if (hasAction) 11f else baseHorizontalPadding(multiline)

    /** Spacing between the icon, the text column, and the action. */
    fun rowSpacing(multiline: Boolean): Float = if (multiline) 14f else 12f

    // --- Slots & column widths ---

    /** Leading glyph slot (spinner / symbol / progress ring). */
    const val ICON_SLOT: Float = 22f

    /** Determinate progress ring diameter (sits inside the icon slot). */
    const val PROGRESS_RING_SIZE: Float = 20f

    /** Leading avatar / thumbnail diameter. */
    const val AVATAR_SIZE: Float = 26f

    /** Single-line text column cap so the capsule never spans the screen. */
    const val TEXT_COLUMN_MAX_WIDTH: Float = 260f

    /** Fixed linear progress bar width on a hugging capsule. */
    const val LINEAR_PROGRESS_WIDTH: Float = 160f

    /** Estimated action button width until its first real measurement lands. */
    const val ACTION_WIDTH_ESTIMATE: Float = 72f

    /** Floor for the multiline probe's reference text width. */
    const val PROBE_MIN_REFERENCE_WIDTH: Float = 120f

    // --- Multiline geometry ---

    const val MULTILINE_SIDE_MARGIN: Float = 20f
    const val MULTILINE_MAX_WIDTH: Float = 440f

    /**
     * Width of a multiline toast: near-full device width, comfortably inset,
     * capped so it never stretches unwieldily wide on tablets / landscape.
     */
    fun multilineWidth(screenWidthDp: Float): Float =
        minOf(MULTILINE_MAX_WIDTH, screenWidthDp - MULTILINE_SIDE_MARGIN * 2)

    // --- Shape ---

    /** Corner radius for a wrapped multiline toast — a rounded rectangle. */
    const val MULTILINE_CORNER_RADIUS: Float = 22f

    /** Corner radius for a single-line toast (title and/or message on one line):
     *  a large radius the surface clamps to half the height, so it reads as a
     *  capsule regardless of how tall a title + message makes it. */
    const val CAPSULE_CORNER_RADIUS: Float = 99f

    // --- Drag ---

    const val DRAG_MIN_DISTANCE: Float = 6f

    /** Translation past which a drag toward the edge commits to dismissal. */
    const val DRAG_COMMIT_DISTANCE: Float = 28f

    /** Predicted end translation past which a flick commits regardless of travel. */
    const val FLICK_DISTANCE: Float = 140f

    /** Damping applied when dragging away from the dismiss edge. */
    const val RUBBER_BAND_FACTOR: Float = 0.35f

    // --- Springs ---
    //
    // Ported from the iOS spring(response:dampingFraction:) values. Compose
    // stiffness is the undamped natural frequency squared: (2π / response)².
    //   stackSpring:  response 0.42 → (2π/0.42)² ≈ 223.8
    //   settleSpring: response 0.35 → (2π/0.35)² ≈ 322.2

    /** The stack's shared motion: entrances, reorders, morphs, width changes. */
    val stackSpring = spring<Float>(dampingRatio = 0.82f, stiffness = 224f)

    /** Snappier settle: drag return, icon swaps. */
    val settleSpring = spring<Float>(dampingRatio = 0.7f, stiffness = 322f)

    // Dp-typed twins of the springs above (identical parameters). `animateDpAsState`
    // needs a `FiniteAnimationSpec<Dp>`; keeping the parameters here — rather than
    // reflecting them off the Float specs — is the single-source rule for motion.
    val stackSpringDp = spring<Dp>(dampingRatio = 0.82f, stiffness = 224f)
    val settleSpringDp = spring<Dp>(dampingRatio = 0.7f, stiffness = 322f)

    // Offset-typed twin for the entrance/drag translation animations.
    val stackSpringOffset = spring<androidx.compose.ui.geometry.Offset>(dampingRatio = 0.82f, stiffness = 224f)

    /** Reduce-Motion analog duration (ms) for the disabled-animations path. */
    const val REDUCED_MOTION_DURATION_MS: Int = 200

    // --- Shake (group re-show with unchanged text) ---

    /** Peak horizontal displacement (dp) of the in-place shake. */
    const val SHAKE_AMPLITUDE: Float = 7f

    /** Left-right oscillations per shake. */
    const val SHAKE_COUNT: Float = 3f

    /** Duration (ms) of the shake — linear, so the sine + falloff shape the motion. */
    const val SHAKE_DURATION_MS: Int = 450

    // Compose default token, referenced so callers can build matching offset/size specs.
    @Suppress("unused")
    val stackVisibilityThreshold: Float = Spring.DefaultDisplacementThreshold
}
