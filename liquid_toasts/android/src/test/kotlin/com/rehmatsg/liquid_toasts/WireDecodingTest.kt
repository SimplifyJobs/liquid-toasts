package com.rehmatsg.liquid_toasts

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

internal class WireDecodingTest {
    @Test
    fun optInt_acceptsIntAndLong() {
        assertEquals(3000, mapOf<String, Any?>("d" to 3000).optInt("d"))
        assertEquals(3000, mapOf<String, Any?>("d" to 3000L).optInt("d"))
        assertNull(mapOf<String, Any?>("d" to "x").optInt("d"))
        assertNull(mapOf<String, Any?>().optInt("d"))
    }

    @Test
    fun optInt_decodesArgbFromEitherWidth() {
        // ARGB may arrive as a Long when the sign bit is set.
        val argb = 0xFFFF3B30L
        assertEquals(argb.toInt(), mapOf<String, Any?>("c" to argb).optInt("c"))
        assertEquals(0x12345678, mapOf<String, Any?>("c" to 0x12345678).optInt("c"))
    }

    @Test
    fun optDouble_acceptsNumericForms() {
        assertEquals(0.5, mapOf<String, Any?>("p" to 0.5).optDouble("p"))
        assertEquals(1.0, mapOf<String, Any?>("p" to 1).optDouble("p"))
        assertEquals(2.0, mapOf<String, Any?>("p" to 2L).optDouble("p"))
        assertNull(mapOf<String, Any?>("p" to "nan").optDouble("p"))
    }

    @Test
    fun optBool_usesDefaultWhenAbsentOrWrongType() {
        assertTrue(mapOf<String, Any?>("b" to true).optBool("b", default = false))
        assertTrue(mapOf<String, Any?>().optBool("b", default = true))
        assertTrue(mapOf<String, Any?>("b" to "true").optBool("b", default = true))
    }

    @Test
    fun byteArray_readsBytesOrNull() {
        val bytes = byteArrayOf(1, 2, 3)
        assertTrue(mapOf<String, Any?>("image" to bytes).byteArray("image").contentEquals(bytes))
        assertNull(mapOf<String, Any?>("image" to "x").byteArray("image"))
    }

    @Test
    fun enumByWireName_matchesNameElseFallsBack() {
        assertEquals(
            ToastSemantic.Error,
            ToastSemantic.fromWire(mapOf("semantic" to "error"), "semantic", ToastSemantic.None),
        )
        // Unknown string → fallback default.
        assertEquals(
            ToastSemantic.None,
            ToastSemantic.fromWire(mapOf("semantic" to "bogus"), "semantic", ToastSemantic.None),
        )
        // Absent key → fallback default.
        assertEquals(
            ToastSemantic.Info,
            ToastSemantic.fromWire(emptyMap(), "semantic", ToastSemantic.Info),
        )
    }

    @Test
    fun contentState_mapsStaticSoftKeyword() {
        assertEquals(
            ToastContentState.Static,
            ToastContentState.fromWire(mapOf("state" to "static"), "state", ToastContentState.Loading),
        )
        assertEquals(
            ToastContentState.Loading,
            ToastContentState.fromWire(mapOf("state" to "loading"), "state", ToastContentState.Static),
        )
    }

    @Test
    fun adaptiveColor_decodesLightDarkPair() {
        val c = AdaptiveColor.fromWire(mapOf("light" to 0xFF000000L, "dark" to 0xFFFFFFFF))
        assertEquals(0xFF000000L.toInt(), c?.light)
        assertEquals(0xFFFFFFFF.toInt(), c?.dark)
        assertNull(AdaptiveColor.fromWire(mapOf("light" to 1))) // missing dark
        assertNull(AdaptiveColor.fromWire(null))
    }
}
