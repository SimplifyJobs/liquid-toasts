package com.rehmatsg.liquid_toasts

/**
 * Wire models mirroring `Models.swift`. Every enum's wire name matches the Dart
 * `.name` string exactly (that string is the contract — see the Dart enums in
 * `lib/src/`), so decoding is a straight name lookup via [enumByWireName].
 *
 * Colors are carried as 32-bit ARGB ints (`0xAARRGGBB`, matching Flutter's
 * `Color.toARGB32()`). The final vector/paint resolution happens in the (later)
 * Compose UI layer; this layer only decodes and computes layout-affecting
 * properties, so it stays free of any Android UI dependency and unit-tests on
 * the JVM.
 */

/** Built-in semantic intent (`ToastSemantic` in Dart). */
internal enum class ToastSemantic(val wire: String) {
    Success("success"),
    Error("error"),
    Warning("warning"),
    Info("info"),
    None("none");

    /** Default SF Symbol name for this intent (null for [None]). */
    val defaultSymbol: String?
        get() = when (this) {
            Success -> "checkmark.circle.fill"
            Error -> "xmark.octagon.fill"
            Warning -> "exclamationmark.triangle.fill"
            Info -> "info.circle.fill"
            None -> null
        }

    /**
     * Adaptive accent color mirroring iOS system colors (auto-adapt to
     * light/dark). [None] has no tint (the UI layer falls back to a neutral).
     */
    val tint: AdaptiveColor?
        get() = when (this) {
            Success -> AdaptiveColor(0xFF34C759.toInt(), 0xFF30D158.toInt())
            Error -> AdaptiveColor(0xFFFF3B30.toInt(), 0xFFFF453A.toInt())
            Warning -> AdaptiveColor(0xFFFF9500.toInt(), 0xFFFF9F0A.toInt())
            Info -> AdaptiveColor(0xFF007AFF.toInt(), 0xFF0A84FF.toInt())
            None -> null
        }

    companion object {
        fun fromWire(map: Map<String, Any?>, key: String, default: ToastSemantic): ToastSemantic =
            map.enumByWireName(key, entries, { it.wire }, default)
    }
}

/** Glass rendering intent (`ToastGlass` in Dart). Decoded and kept, never rendered. */
internal enum class ToastGlassIntent(val wire: String) {
    Adaptive("adaptive"),
    Liquid("liquid"),
    Frosted("frosted"),
    Solid("solid"),
    None("none");

    companion object {
        fun fromWireOrNull(map: Map<String, Any?>, key: String): ToastGlassIntent? {
            val raw = map[key] as? String ?: return null
            return entries.firstOrNull { it.wire == raw }
        }
    }
}

/**
 * Content state. The Dart wire value `static` collides with the Kotlin soft
 * keyword, so the entries are [Static]/[Loading] with explicit wire strings.
 */
internal enum class ToastContentState(val wire: String) {
    Static("static"),
    Loading("loading");

    companion object {
        fun fromWire(map: Map<String, Any?>, key: String, default: ToastContentState): ToastContentState =
            map.enumByWireName(key, entries, { it.wire }, default)
    }
}

/** Haptic fired on appear (`ToastHaptic` in Dart). */
internal enum class ToastHapticKind(val wire: String) {
    None("none"),
    Success("success"),
    Warning("warning"),
    Error("error"),
    Selection("selection");

    companion object {
        fun fromWire(map: Map<String, Any?>, key: String, default: ToastHapticKind): ToastHapticKind =
            map.enumByWireName(key, entries, { it.wire }, default)
    }
}

/** Animated icon effect (`ToastSymbolEffect` in Dart). */
internal enum class ToastSymbolEffect(val wire: String) {
    None("none"),
    Bounce("bounce"),
    Pulse("pulse"),
    Wiggle("wiggle"),
    Rotate("rotate"),
    Breathe("breathe"),
    VariableColor("variableColor"),
    DrawOn("drawOn");

    companion object {
        fun fromWire(map: Map<String, Any?>, key: String, default: ToastSymbolEffect): ToastSymbolEffect =
            map.enumByWireName(key, entries, { it.wire }, default)
    }
}

/** How a determinate progress value renders (`ToastProgressStyle` in Dart). */
internal enum class ToastProgressStyle(val wire: String) {
    Linear("linear"),
    Circular("circular");

    companion object {
        fun fromWire(map: Map<String, Any?>, key: String, default: ToastProgressStyle): ToastProgressStyle =
            map.enumByWireName(key, entries, { it.wire }, default)
    }
}

/**
 * Where a toast anchors (`ToastPosition` in Dart). Alignment helpers mirror the
 * iOS computed properties; the concrete Compose `Alignment` mapping lives in the
 * UI layer (this layer only needs the top/bottom/horizontal classification).
 */
internal enum class ToastPositionModel(val wire: String) {
    TopCenter("topCenter"),
    TopLeading("topLeading"),
    TopTrailing("topTrailing"),
    Center("center"),
    BottomCenter("bottomCenter"),
    BottomLeading("bottomLeading"),
    BottomTrailing("bottomTrailing");

    val isTop: Boolean get() = this == TopCenter || this == TopLeading || this == TopTrailing
    val isBottom: Boolean get() = this == BottomCenter || this == BottomLeading || this == BottomTrailing

    /** -1 leading, 0 center, 1 trailing — the horizontal bias for this position. */
    val horizontalBias: Int
        get() = when (this) {
            TopLeading, BottomLeading -> -1
            TopTrailing, BottomTrailing -> 1
            else -> 0
        }

    companion object {
        fun fromWire(map: Map<String, Any?>, key: String, default: ToastPositionModel): ToastPositionModel =
            map.enumByWireName(key, entries, { it.wire }, default)
    }
}

/** Semantic role of the action button (`ToastActionRole` in Dart). */
internal enum class ActionRole(val wire: String) {
    Primary("primary"),
    Secondary("secondary"),
    Destructive("destructive"),
    Success("success"),
    Warning("warning"),
    Neutral("neutral");

    /**
     * Default role color mirroring iOS. [Primary] maps to an accent blue,
     * [Secondary]/[Neutral] to muted foregrounds; the UI layer may further
     * adapt these against the surface.
     */
    val color: AdaptiveColor
        get() = when (this) {
            Primary -> AdaptiveColor(0xFF007AFF.toInt(), 0xFF0A84FF.toInt())
            Secondary -> AdaptiveColor(0x993C3C43.toInt(), 0x99EBEBF5.toInt())
            Destructive -> AdaptiveColor(0xFFFF3B30.toInt(), 0xFFFF453A.toInt())
            Success -> AdaptiveColor(0xFF34C759.toInt(), 0xFF30D158.toInt())
            Warning -> AdaptiveColor(0xFFFF9500.toInt(), 0xFFFF9F0A.toInt())
            Neutral -> AdaptiveColor(0xB3000000.toInt(), 0xB3FFFFFF.toInt())
        }

    companion object {
        fun fromWire(map: Map<String, Any?>, key: String, default: ActionRole): ActionRole =
            map.enumByWireName(key, entries, { it.wire }, default)
    }
}

/**
 * A `{light, dark}` ARGB32 color pair decoded from the wire, resolved natively
 * against the current color scheme.
 */
internal data class AdaptiveColor(val light: Int, val dark: Int) {
    fun resolve(isDark: Boolean): Int = if (isDark) dark else light

    companion object {
        /** Decodes a `{light, dark}` wire map, or null when absent/malformed. */
        fun fromWire(value: Any?): AdaptiveColor? {
            @Suppress("UNCHECKED_CAST")
            val map = value as? Map<String, Any?> ?: return null
            val light = map.optInt("light") ?: return null
            val dark = map.optInt("dark") ?: return null
            return AdaptiveColor(light, dark)
        }
    }
}

/** Per-toast visual override (`ToastStyleOverride` in Dart). */
internal data class ToastStyleModel(
    val tint: AdaptiveColor?,
    val background: AdaptiveColor?,
    val foreground: AdaptiveColor?,
    val iconColor: AdaptiveColor?,
    val glass: ToastGlassIntent?,
    val cornerRadius: Double?,
    val symbolEffect: ToastSymbolEffect,
) {
    companion object {
        fun fromWire(value: Any?): ToastStyleModel? {
            @Suppress("UNCHECKED_CAST")
            val map = value as? Map<String, Any?> ?: return null
            return ToastStyleModel(
                tint = AdaptiveColor.fromWire(map["tint"]),
                background = AdaptiveColor.fromWire(map["background"]),
                foreground = AdaptiveColor.fromWire(map["foreground"]),
                iconColor = AdaptiveColor.fromWire(map["iconColor"]),
                glass = ToastGlassIntent.fromWireOrNull(map, "glass"),
                cornerRadius = map.optDouble("cornerRadius"),
                symbolEffect = ToastSymbolEffect.fromWire(map, "symbolEffect", ToastSymbolEffect.None),
            )
        }
    }
}

/** The single (at most one) action button (`ToastAction` in Dart). */
internal data class ToastActionModel(
    val actionId: String,
    val label: String,
    val role: ActionRole,
    val color: AdaptiveColor?,
    val dismissOnPress: Boolean,
    val loadingOnPress: Boolean,
) {
    companion object {
        fun fromWire(value: Any?): ToastActionModel? {
            @Suppress("UNCHECKED_CAST")
            val map = value as? Map<String, Any?> ?: return null
            val actionId = map.optString("actionId") ?: return null
            val label = map.optString("label") ?: return null
            return ToastActionModel(
                actionId = actionId,
                label = label,
                role = ActionRole.fromWire(map, "role", ActionRole.Primary),
                color = AdaptiveColor.fromWire(map["color"]),
                dismissOnPress = map.optBool("dismissOnPress", default = true),
                loadingOnPress = map.optBool("loadingOnPress", default = false),
            )
        }
    }
}

/**
 * Reference-equality wrapper so [ToastModel] can synthesize `==` without ever
 * comparing pixel data — a decoded bitmap is immutable, so identity is the right
 * equivalence (mirrors `ToastImage` in Swift). [pixels] is typed `Any?` here so
 * this layer stays UI-free; the UI layer holds an actual `Bitmap`.
 */
internal class ToastImage(val pixels: Any) {
    override fun equals(other: Any?): Boolean = other is ToastImage && other.pixels === pixels
    override fun hashCode(): Int = System.identityHashCode(pixels)
}

/**
 * Immutable toast model, mirroring `ToastModel`. Runtime-only flags
 * ([isActionBusy], [hasEntered], [image]) are NOT decoded from the wire — they
 * live on the model so flipping one re-renders only the affected row.
 */
internal data class ToastModel(
    val id: String,
    val message: String,
    val title: String?,
    val icon: String?,
    /** The decoded leading image; null until the async decode lands / for none. */
    val image: ToastImage? = null,
    /**
     * True when the wire payload carried image bytes. Reserves the avatar slot
     * from the first frame so the layout doesn't jump when the pixels land; the
     * manager clears it if the decode fails (the slot then collapses).
     */
    val expectsImage: Boolean,
    val semantic: ToastSemantic,
    val style: ToastStyleModel?,
    val position: ToastPositionModel,
    val state: ToastContentState,
    val persistent: Boolean,
    val durationMs: Int?,
    val useDynamicIslandOrigin: Boolean,
    val progress: Double?,
    val progressStyle: ToastProgressStyle,
    val groupKey: String?,
    val haptic: ToastHapticKind,
    val semanticsLabel: String?,
    val maxLines: Int,
    val titleMaxLines: Int,
    val tapToDismiss: Boolean,
    val hasTap: Boolean,
    val action: ToastActionModel?,
    /** True while an async `loadingOnPress` action runs — the button spins. */
    val isActionBusy: Boolean = false,
    /** True once the entrance transition has played (suppresses re-entrance on reattach). */
    val hasEntered: Boolean = false,
    /**
     * The row's view identity, normally the same as [id] (null → use [id]). Held
     * stable across an in-place group re-show (a "shake") so the row shakes rather
     * than exit+entering, while [id] still swaps to the newest wire id.
     */
    val identity: String? = null,
    /**
     * Bumped each time an already-visible group toast is re-shown with unchanged
     * text: the row observes it and plays a one-shot horizontal shake.
     */
    val shakeToken: Int = 0,
) {
    /** Stable Compose row key — [identity] when set, else the wire [id]. */
    val rowKey: String get() = identity ?: id

    /**
     * Applies a fresh model's content onto this toast, preserving [id] (so the UI
     * morphs the existing surface) and clearing [isActionBusy] (a morph
     * supersedes any in-flight action spinner). Mirrors `applyContent(from:)`.
     */
    fun applyingContent(from: ToastModel): ToastModel = copy(
        message = from.message,
        title = from.title,
        icon = from.icon,
        image = from.image,
        expectsImage = from.expectsImage,
        semantic = from.semantic,
        style = from.style,
        position = from.position,
        state = from.state,
        persistent = from.persistent,
        durationMs = from.durationMs,
        progress = from.progress,
        progressStyle = from.progressStyle,
        haptic = from.haptic,
        semanticsLabel = from.semanticsLabel,
        maxLines = from.maxLines,
        titleMaxLines = from.titleMaxLines,
        tapToDismiss = from.tapToDismiss,
        hasTap = from.hasTap,
        action = from.action,
        isActionBusy = false,
    )

    /** The SF Symbol to render: explicit icon wins, else the semantic default. */
    val resolvedSymbol: String?
        get() = icon?.takeIf { it.isNotEmpty() } ?: semantic.defaultSymbol

    /** A leading glyph (spinner or symbol) renders. */
    val showsIcon: Boolean
        get() = state == ToastContentState.Loading || resolvedSymbol != null

    /** A determinate circular progress ring renders in place of the leading icon. */
    val showsCircularProgress: Boolean
        get() = progress != null && progressStyle == ToastProgressStyle.Circular

    /** Whether anything occupies the leading slot (image / ring / spinner / icon). */
    val showsLeadingSlot: Boolean
        get() = expectsImage || image != null || showsCircularProgress || showsIcon

    /** Auto-dismiss interval in ms, or null when persistent / loading. */
    val autoDurationMs: Long?
        get() {
            if (persistent || state == ToastContentState.Loading) return null
            val ms = durationMs ?: 3000
            return ms.coerceIn(1500, 10000).toLong()
        }

    val accessibilityText: String
        get() {
            semanticsLabel?.takeIf { it.isNotEmpty() }?.let { return it }
            return listOfNotNull(title, message).joinToString(", ")
        }

    companion object {
        /**
         * Decodes a wire map into a model, or null when the required `id`/`message`
         * are missing. `id` is passed explicitly (it may live in the map under
         * `"id"`, but callers already hold it) — matching the plugin routing where
         * the map is the full `show`/`update` envelope body.
         */
        fun fromWire(map: Map<String, Any?>, id: String): ToastModel? {
            val message = map.optString("message") ?: return null
            return ToastModel(
                id = id,
                message = message,
                title = map.optString("title"),
                icon = map.optString("icon"),
                expectsImage = map.byteArray("image") != null,
                semantic = ToastSemantic.fromWire(map, "semantic", ToastSemantic.None),
                style = ToastStyleModel.fromWire(map["style"]),
                position = ToastPositionModel.fromWire(map, "position", ToastPositionModel.TopCenter),
                state = ToastContentState.fromWire(map, "state", ToastContentState.Static),
                persistent = map.optBool("persistent", default = false),
                durationMs = map.optInt("durationMs"),
                useDynamicIslandOrigin = map.optBool("useDynamicIslandOrigin", default = true),
                progress = map.optDouble("progress"),
                progressStyle = ToastProgressStyle.fromWire(map, "progressStyle", ToastProgressStyle.Linear),
                groupKey = map.optString("groupKey"),
                haptic = ToastHapticKind.fromWire(map, "haptic", ToastHapticKind.None),
                semanticsLabel = map.optString("semanticsLabel"),
                maxLines = map.optInt("maxLines") ?: 1,
                titleMaxLines = map.optInt("titleMaxLines") ?: 1,
                tapToDismiss = map.optBool("tapToDismiss", default = true),
                hasTap = map.optBool("hasTap", default = false),
                action = ToastActionModel.fromWire(map["action"]),
            )
        }
    }
}
