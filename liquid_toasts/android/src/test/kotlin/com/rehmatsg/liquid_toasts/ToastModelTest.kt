package com.rehmatsg.liquid_toasts

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

internal class ToastModelTest {
    private fun wire(vararg pairs: Pair<String, Any?>): Map<String, Any?> =
        mapOf("message" to "hi", *pairs)

    @Test
    fun autoDuration_defaultsTo3000() {
        val m = ToastModel.fromWire(wire(), "id")!!
        assertEquals(3000L, m.autoDurationMs)
    }

    @Test
    fun autoDuration_clampsToRange() {
        assertEquals(1500L, ToastModel.fromWire(wire("durationMs" to 100), "id")!!.autoDurationMs)
        assertEquals(10000L, ToastModel.fromWire(wire("durationMs" to 999999), "id")!!.autoDurationMs)
        assertEquals(4000L, ToastModel.fromWire(wire("durationMs" to 4000), "id")!!.autoDurationMs)
    }

    @Test
    fun autoDuration_nullForPersistentAndLoading() {
        assertNull(ToastModel.fromWire(wire("persistent" to true), "id")!!.autoDurationMs)
        assertNull(ToastModel.fromWire(wire("state" to "loading"), "id")!!.autoDurationMs)
    }

    @Test
    fun accessibilityText_prefersLabelThenTitleMessage() {
        assertEquals(
            "custom",
            ToastModel.fromWire(wire("semanticsLabel" to "custom", "title" to "T"), "id")!!.accessibilityText,
        )
        assertEquals(
            "T, hi",
            ToastModel.fromWire(wire("title" to "T"), "id")!!.accessibilityText,
        )
        assertEquals("hi", ToastModel.fromWire(wire(), "id")!!.accessibilityText)
    }

    @Test
    fun resolvedSymbol_explicitIconWinsElseSemanticDefault() {
        assertEquals("star.fill", ToastModel.fromWire(wire("icon" to "star.fill", "semantic" to "success"), "id")!!.resolvedSymbol)
        assertEquals("checkmark.circle.fill", ToastModel.fromWire(wire("semantic" to "success"), "id")!!.resolvedSymbol)
        assertNull(ToastModel.fromWire(wire(), "id")!!.resolvedSymbol)
    }

    @Test
    fun leadingSlotFlags() {
        val plain = ToastModel.fromWire(wire(), "id")!!
        assertFalse(plain.showsLeadingSlot)
        val loading = ToastModel.fromWire(wire("state" to "loading"), "id")!!
        assertTrue(loading.showsIcon)
        assertTrue(loading.showsLeadingSlot)
        val ring = ToastModel.fromWire(wire("progress" to 0.5, "progressStyle" to "circular"), "id")!!
        assertTrue(ring.showsCircularProgress)
        val withImage = ToastModel.fromWire(wire("image" to byteArrayOf(1)), "id")!!
        assertTrue(withImage.expectsImage)
        assertTrue(withImage.showsLeadingSlot)
    }

    @Test
    fun fromWire_returnsNullWithoutMessage() {
        assertNull(ToastModel.fromWire(mapOf("title" to "x"), "id"))
    }

    @Test
    fun applyingContent_clearsBusyAndKeepsId() {
        val a = ToastModel.fromWire(wire("title" to "A"), "id1")!!.copy(isActionBusy = true)
        val b = ToastModel.fromWire(wire("title" to "B"), "id2")!!
        val merged = a.applyingContent(b)
        assertEquals("id1", merged.id)
        assertEquals("B", merged.title)
        assertFalse(merged.isActionBusy)
    }
}
