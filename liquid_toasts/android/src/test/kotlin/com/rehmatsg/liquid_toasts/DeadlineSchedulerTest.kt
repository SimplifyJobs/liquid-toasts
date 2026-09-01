package com.rehmatsg.liquid_toasts

import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

@OptIn(ExperimentalCoroutinesApi::class)
internal class DeadlineSchedulerTest {
    /**
     * A test harness that keeps the scheduler's watcher-coroutine virtual time
     * and its injected wall-clock in lockstep: [advance] moves both by the same
     * amount, so `delay(...)` and the `clock()`-based deadline math agree.
     */
    private class Harness(val scope: TestScope) {
        var now: Long = 0L
        val fired = mutableListOf<Pair<String, String>>()

        // Run watcher jobs on the test's backgroundScope so they share the same
        // virtual-time scheduler as `advance` and are auto-cancelled at test end.
        val scheduler = DeadlineScheduler(
            scope = scope.backgroundScope,
            clock = { now },
        ).also { s ->
            s.onExpire = { id, reason -> fired += id to reason }
        }

        fun advance(ms: Long) {
            now += ms
            scope.testScheduler.advanceTimeBy(ms)
            scope.testScheduler.runCurrent()
        }
    }

    private fun harness(block: TestScope.(Harness) -> Unit) = runTest {
        block(Harness(this))
    }

    @Test
    fun arm_firesTimeoutAtDeadline() = harness { h ->
        h.scheduler.arm("a", 1000)
        h.advance(999)
        assertTrue(h.fired.isEmpty())
        h.advance(1)
        assertEquals(listOf("a" to "timeout"), h.fired)
    }

    @Test
    fun disarm_preventsFire_exactlyOnce() = harness { h ->
        h.scheduler.arm("a", 1000)
        h.advance(500)
        h.scheduler.disarm("a")
        h.advance(1000)
        assertTrue(h.fired.isEmpty())
    }

    @Test
    fun pause_banksRemaining_resumeReArms() = harness { h ->
        h.scheduler.arm("a", 1000)
        h.advance(400) // 600ms remaining
        h.scheduler.pause("a")
        h.advance(5000) // time passes while paused; nothing fires
        assertTrue(h.fired.isEmpty())
        h.scheduler.resume("a")
        h.advance(599)
        assertTrue(h.fired.isEmpty())
        h.advance(1)
        assertEquals(listOf("a" to "timeout"), h.fired)
    }

    @Test
    fun pause_noOpWithoutLiveDeadline() = harness { h ->
        h.scheduler.pause("ghost") // persistent/loading has no deadline
        h.scheduler.resume("ghost")
        h.advance(10000)
        assertTrue(h.fired.isEmpty())
    }

    @Test
    fun background_keepsDeadlines_foregroundReArmsLive() = harness { h ->
        h.scheduler.arm("a", 2000)
        h.advance(500)
        h.scheduler.appDidEnterBackground()
        // Watcher cancelled: crossing the deadline while backgrounded must not fire.
        h.advance(3000)
        assertTrue(h.fired.isEmpty(), "backgrounded toast must not fire from a live watcher")
    }

    @Test
    fun foreground_firesPastDueAsAppBackgrounded() = harness { h ->
        h.scheduler.arm("a", 1000)
        h.scheduler.arm("b", 5000)
        h.advance(500)
        h.scheduler.appDidEnterBackground()
        h.advance(2000) // now past a's deadline, before b's
        h.scheduler.appWillEnterForeground()
        runCurrent()
        assertEquals(listOf("a" to "appBackgrounded"), h.fired)
        // b was live at foreground → re-armed; fires on timeout later.
        h.advance(2500)
        assertEquals(listOf("a" to "appBackgrounded", "b" to "timeout"), h.fired)
    }

    @Test
    fun arm_nullDurationDisarms() = harness { h ->
        h.scheduler.arm("a", 1000)
        h.scheduler.arm("a", null) // re-arm persistent
        h.advance(5000)
        assertTrue(h.fired.isEmpty())
    }

    @Test
    fun disarmAll_clearsEverything() = harness { h ->
        h.scheduler.arm("a", 1000)
        h.scheduler.arm("b", 1000)
        h.scheduler.disarmAll()
        h.advance(5000)
        assertTrue(h.fired.isEmpty())
    }
}
