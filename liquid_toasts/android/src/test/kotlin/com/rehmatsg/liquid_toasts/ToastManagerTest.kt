package com.rehmatsg.liquid_toasts

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.plus
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

@OptIn(ExperimentalCoroutinesApi::class)
internal class ToastManagerTest {
    private class Harness(scope: TestScope) {
        val scheduler = scope.testScheduler
        var now: Long = 1_000L
        val events = mutableListOf<Map<String, Any?>>()
        val haptics = mutableListOf<ToastHapticKind>()
        var decodeResult: Any? = Any()
        var decodeCalls = 0

        // Unconfined test dispatcher (child of backgroundScope so it is
        // auto-cancelled): image-decode launches run eagerly and inline, while
        // the internal scheduler's `delay`-based timers still honor virtual time.
        private val managerScope: CoroutineScope =
            scope.backgroundScope + UnconfinedTestDispatcher(scope.testScheduler)

        val manager = ToastManager(
            scope = managerScope,
            clock = { now },
            decodeImage = { decodeCalls++; decodeResult },
        ).also {
            it.onEvent = { e -> events += e }
            it.onHaptic = { h -> haptics += h }
        }

        val toasts get() = manager.toasts.value
        fun dismissedReasons() = events.filter { it["event"] == "dismissed" }.map { it["id"] to it["reason"] }
    }

    private fun model(
        id: String,
        message: String = "m",
        groupKey: String? = null,
        position: ToastPositionModel = ToastPositionModel.TopCenter,
        persistent: Boolean = false,
        state: ToastContentState = ToastContentState.Static,
        durationMs: Int? = 3000,
        haptic: ToastHapticKind = ToastHapticKind.None,
        tapToDismiss: Boolean = true,
        hasTap: Boolean = false,
        action: ToastActionModel? = null,
        expectsImage: Boolean = false,
    ) = ToastModel(
        id = id,
        message = message,
        title = null,
        icon = null,
        expectsImage = expectsImage,
        semantic = ToastSemantic.None,
        style = null,
        position = position,
        state = state,
        persistent = persistent,
        durationMs = durationMs,
        useDynamicIslandOrigin = true,
        progress = null,
        progressStyle = ToastProgressStyle.Linear,
        groupKey = groupKey,
        haptic = haptic,
        semanticsLabel = null,
        maxLines = 1,
        titleMaxLines = 1,
        tapToDismiss = tapToDismiss,
        hasTap = hasTap,
        action = action,
    )

    private fun action(id: String = "a0", dismissOnPress: Boolean = true, loadingOnPress: Boolean = false) =
        ToastActionModel(id, "OK", ActionRole.Primary, null, dismissOnPress, loadingOnPress)

    @Test
    fun present_emitsShownWithStackIndexAndTs() = runTest {
        val h = Harness(this)
        h.manager.present(model("t1"))
        val shown = h.events.single { it["event"] == "shown" }
        assertEquals("t1", shown["id"])
        assertEquals(0, shown["stackIndex"])
        assertEquals(1_000L, shown["tsMs"])
        assertEquals(1, h.toasts.size)
    }

    @Test
    fun timeout_emitsDismissedTimeout() = runTest {
        val h = Harness(this)
        h.manager.present(model("t1", durationMs = 2000))
        h.now += 2000
        this.testScheduler.advanceTimeBy(2000)
        this.testScheduler.runCurrent()
        assertEquals(listOf("t1" to "timeout"), h.dismissedReasons())
        assertTrue(h.toasts.isEmpty())
    }

    @Test
    fun groupKey_replacesInPlacePreservingIndex() = runTest {
        val h = Harness(this)
        h.manager.present(model("first"))
        h.manager.present(model("second", groupKey = "g"))
        h.manager.present(model("third"))
        // "second" at index 1; replace it via same groupKey and changed text.
        h.manager.present(model("second2", message = "changed", groupKey = "g"))
        assertEquals(listOf("first", "second2", "third"), h.toasts.map { it.id })
        assertTrue(h.dismissedReasons().contains("second" to "replaced"))
    }

    @Test
    fun groupKey_unchangedText_shakesInPlaceKeepingRowIdentity() = runTest {
        val h = Harness(this)
        h.manager.present(model("first", message = "hi", groupKey = "g"))
        val rowKeyBefore = h.toasts.single().rowKey
        assertEquals(0, h.toasts.single().shakeToken)

        // Re-show the same group with identical text: shake in place.
        h.manager.present(model("second", message = "hi", groupKey = "g"))
        val shaken = h.toasts.single()
        // Wire id adopts the newest show (newest handle controls the toast)...
        assertEquals("second", shaken.id)
        // ...but the row identity is held stable so the row shakes, not re-enters.
        assertEquals(rowKeyBefore, shaken.rowKey)
        assertEquals(1, shaken.shakeToken)
        assertTrue(h.dismissedReasons().contains("first" to "replaced"))

        // A second identical re-show keeps the same identity and bumps the token.
        h.manager.present(model("third", message = "hi", groupKey = "g"))
        val shakenAgain = h.toasts.single()
        assertEquals("third", shakenAgain.id)
        assertEquals(rowKeyBefore, shakenAgain.rowKey)
        assertEquals(2, shakenAgain.shakeToken)
    }

    @Test
    fun groupKey_changedText_doesNotShake() = runTest {
        val h = Harness(this)
        h.manager.present(model("first", message = "hi", groupKey = "g"))
        h.manager.present(model("second", message = "bye", groupKey = "g"))
        val replaced = h.toasts.single()
        assertEquals("second", replaced.id)
        // Changed text: standard replace, no stable identity, no shake token.
        assertEquals("second", replaced.rowKey)
        assertEquals(0, replaced.shakeToken)
    }

    @Test
    fun maxVisible_dropOldestDismissesVictimWithReplaced() = runTest {
        val h = Harness(this)
        h.manager.maxVisible = 2
        h.manager.dropOldest = true
        h.manager.present(model("a"))
        h.manager.present(model("b"))
        h.manager.present(model("c"))
        assertEquals(listOf("b", "c"), h.toasts.map { it.id })
        assertTrue(h.dismissedReasons().contains("a" to "replaced"))
    }

    @Test
    fun maxVisible_dropNewestDropsIncoming() = runTest {
        val h = Harness(this)
        h.manager.maxVisible = 2
        h.manager.dropOldest = false
        h.manager.present(model("a"))
        h.manager.present(model("b"))
        h.manager.present(model("c"))
        assertEquals(listOf("a", "b"), h.toasts.map { it.id })
        assertTrue(h.dismissedReasons().contains("c" to "replaced"))
    }

    @Test
    fun maxVisible_persistentToastSurvivesOverflow_evictsOldestTransient() = runTest {
        val h = Harness(this)
        h.manager.maxVisible = 2
        h.manager.dropOldest = true
        h.manager.present(model("p", persistent = true))
        h.manager.present(model("a"))
        h.manager.present(model("b")) // overflow: evict oldest *transient*, not the persistent one
        assertEquals(listOf("p", "b"), h.toasts.map { it.id })
        assertTrue(h.dismissedReasons().contains("a" to "replaced"))
        // The persistent toast is never force-dismissed by overflow.
        assertFalse(h.dismissedReasons().any { it.first == "p" })
    }

    @Test
    fun maxVisible_loadingToastExemptFromEviction() = runTest {
        val h = Harness(this)
        h.manager.maxVisible = 2
        h.manager.dropOldest = true
        h.manager.present(model("spin", state = ToastContentState.Loading))
        h.manager.present(model("a"))
        h.manager.present(model("b")) // a loading spinner has no deadline → exempt
        assertEquals(listOf("spin", "b"), h.toasts.map { it.id })
        assertTrue(h.dismissedReasons().contains("a" to "replaced"))
        assertFalse(h.dismissedReasons().any { it.first == "spin" })
    }

    @Test
    fun maxVisible_allPersistentExceedsSoftCap_noEviction() = runTest {
        val h = Harness(this)
        h.manager.maxVisible = 2
        h.manager.dropOldest = true
        h.manager.present(model("p1", persistent = true))
        h.manager.present(model("p2", persistent = true))
        h.manager.present(model("p3", persistent = true)) // nothing evictable → soft overflow
        assertEquals(listOf("p1", "p2", "p3"), h.toasts.map { it.id })
        assertTrue(h.dismissedReasons().isEmpty())
    }

    @Test
    fun maxVisible_dropNewest_rejectsIncomingTransientButKeepsPersistent() = runTest {
        val h = Harness(this)
        h.manager.maxVisible = 2
        h.manager.dropOldest = false
        h.manager.present(model("p", persistent = true))
        h.manager.present(model("a"))
        h.manager.present(model("b")) // drop-newest rejects the incoming transient
        assertEquals(listOf("p", "a"), h.toasts.map { it.id })
        assertTrue(h.dismissedReasons().contains("b" to "replaced"))
        assertFalse(h.dismissedReasons().any { it.first == "p" })
    }

    @Test
    fun teardown_exactlyOnce() = runTest {
        val h = Harness(this)
        h.manager.present(model("t1"))
        assertTrue(h.manager.dismiss("t1", "manual"))
        assertFalse(h.manager.dismiss("t1", "manual"))
        assertEquals(1, h.dismissedReasons().count { it == ("t1" to "manual") })
    }

    @Test
    fun flushAll_isSilent() = runTest {
        val h = Harness(this)
        h.manager.present(model("t1"))
        h.manager.present(model("t2"))
        h.events.clear()
        h.manager.flushAll()
        assertTrue(h.toasts.isEmpty())
        assertTrue(h.events.isEmpty())
    }

    @Test
    fun handleActionTap_dismissOnPress() = runTest {
        val h = Harness(this)
        h.manager.present(model("t1", action = action(dismissOnPress = true)))
        h.manager.handleActionTap("t1")
        assertTrue(h.events.any { it["event"] == "actionTapped" && it["actionId"] == "a0" })
        assertTrue(h.dismissedReasons().contains("t1" to "action"))
    }

    @Test
    fun handleActionTap_loadingSetsBusyAndDisarms() = runTest {
        val h = Harness(this)
        h.manager.present(model("t1", durationMs = 2000, action = action(loadingOnPress = true, dismissOnPress = false)))
        h.manager.handleActionTap("t1")
        assertTrue(h.toasts.single().isActionBusy)
        // Auto-dismiss disarmed: crossing the old deadline must not tear it down.
        h.now += 5000
        this.testScheduler.advanceTimeBy(5000)
        this.testScheduler.runCurrent()
        assertTrue(h.toasts.isNotEmpty())
        assertFalse(h.dismissedReasons().any { it.first == "t1" })
    }

    @Test
    fun finishAction_clearsBusyAndReArms() = runTest {
        val h = Harness(this)
        h.manager.present(model("t1", durationMs = 2000, action = action(loadingOnPress = true, dismissOnPress = false)))
        h.manager.handleActionTap("t1")
        h.manager.finishAction("t1")
        assertFalse(h.toasts.single().isActionBusy)
        h.now += 2000
        this.testScheduler.advanceTimeBy(2000)
        this.testScheduler.runCurrent()
        assertTrue(h.dismissedReasons().contains("t1" to "timeout"))
    }

    @Test
    fun handleBodyTap_emitsTappedAndDismisses() = runTest {
        val h = Harness(this)
        h.manager.present(model("t1", hasTap = true, tapToDismiss = true))
        h.manager.handleBodyTap("t1")
        assertTrue(h.events.any { it["event"] == "tapped" && it["id"] == "t1" })
        assertTrue(h.dismissedReasons().contains("t1" to "tap"))
    }

    @Test
    fun handleSwipe_dismissesWithSwipe() = runTest {
        val h = Harness(this)
        h.manager.present(model("t1"))
        h.manager.handleSwipe("t1")
        assertTrue(h.dismissedReasons().contains("t1" to "swipe"))
    }

    @Test
    fun dismissAll_returnsIdsAndEmits() = runTest {
        val h = Harness(this)
        h.manager.present(model("a"))
        h.manager.present(model("b"))
        val ids = h.manager.dismissAll("dismissAll")
        assertEquals(listOf("a", "b"), ids)
        assertTrue(h.dismissedReasons().contains("a" to "dismissAll"))
        assertTrue(h.dismissedReasons().contains("b" to "dismissAll"))
    }

    @Test
    fun present_firesHapticWhenSet() = runTest {
        val h = Harness(this)
        h.manager.present(model("t1", haptic = ToastHapticKind.Success))
        assertEquals(listOf(ToastHapticKind.Success), h.haptics)
    }

    @Test
    fun stackGeneration_bumpsOnIdSetChangeOnly() = runTest {
        val h = Harness(this)
        val g0 = h.manager.stackGeneration.intValue
        h.manager.present(model("t1"))
        val g1 = h.manager.stackGeneration.intValue
        assertTrue(g1 > g0)
        // A content-only update (same id set) must not bump.
        h.manager.update("t1", model("t1", message = "changed"))
        assertEquals(g1, h.manager.stackGeneration.intValue)
        h.manager.dismiss("t1", "manual")
        assertTrue(h.manager.stackGeneration.intValue > g1)
    }

    @Test
    fun imageDecode_attachesPixelsWhenCurrent() = runTest {
        val h = Harness(this)
        h.manager.present(model("t1", expectsImage = true), imageData = byteArrayOf(1, 2))
        this.advanceUntilIdle()
        assertTrue(h.toasts.single().image != null)
        assertEquals(1, h.decodeCalls)
    }

    @Test
    fun imageDecode_failureCollapsesSlot() = runTest {
        val h = Harness(this)
        h.decodeResult = null
        h.manager.present(model("t1", expectsImage = true), imageData = byteArrayOf(1))
        this.advanceUntilIdle()
        assertFalse(h.toasts.single().expectsImage)
        assertNull(h.toasts.single().image)
    }

    @Test
    fun update_returnsFalseForUnknownId() = runTest {
        val h = Harness(this)
        assertFalse(h.manager.update("nope", model("nope")))
    }
}
