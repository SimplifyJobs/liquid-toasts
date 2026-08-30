package com.rehmatsg.liquid_toasts

/**
 * Decoding helpers for method-channel payloads. Flutter's [StandardMessageCodec]
 * bridges Dart ints as either `Int` or `Long` and doubles as `Double`, so plain
 * casts on the primitive types are unreliable — always go through these. This is
 * the Android analog of `WireDecoding.swift`'s NSNumber-aware accessors.
 */
internal fun Map<String, Any?>.optString(key: String): String? = this[key] as? String

/** Reads an int, accepting the `Int` OR `Long` the codec may deliver. */
internal fun Map<String, Any?>.optInt(key: String): Int? = when (val v = this[key]) {
    is Int -> v
    is Long -> v.toInt()
    is Number -> v.toInt()
    else -> null
}

/** Reads a double, accepting any numeric representation (`Int`/`Long`/`Double`/`Float`). */
internal fun Map<String, Any?>.optDouble(key: String): Double? = when (val v = this[key]) {
    is Double -> v
    is Float -> v.toDouble()
    is Int -> v.toDouble()
    is Long -> v.toDouble()
    is Number -> v.toDouble()
    else -> null
}

internal fun Map<String, Any?>.optBool(key: String, default: Boolean): Boolean =
    when (val v = this[key]) {
        is Boolean -> v
        else -> default
    }

@Suppress("UNCHECKED_CAST")
internal fun Map<String, Any?>.optMap(key: String): Map<String, Any?>? =
    this[key] as? Map<String, Any?>

/** Image bytes arrive as a `ByteArray` (from a Dart `Uint8List`). */
internal fun Map<String, Any?>.byteArray(key: String): ByteArray? = this[key] as? ByteArray

/**
 * Decodes a wire enum by its Dart `.name` string, falling back to [default] when
 * the key is absent or holds an unknown value. [values] is the enum's entries
 * (pass `EnumType.entries`); each entry's wire name comes from [wireName].
 */
internal fun <E> Map<String, Any?>.enumByWireName(
    key: String,
    values: List<E>,
    wireName: (E) -> String,
    default: E,
): E {
    val raw = this[key] as? String ?: return default
    return values.firstOrNull { wireName(it) == raw } ?: default
}
