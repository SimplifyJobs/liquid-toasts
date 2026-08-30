package com.rehmatsg.liquid_toasts

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

/**
 * Owns all auto-dismiss timing for the toast stack: wall-clock deadlines (so
 * backgrounding can't corrupt them), the coroutines that fire them, and the
 * banked remaining time for toasts paused mid-interaction. A line-for-line port
 * of `DeadlineScheduler.swift`.
 *
 * Deliberately knows nothing about the stack itself — the manager guards
 * existence and reacts to [onExpire]. Flutter-free and Android-UI-free by design,
 * so it unit-tests under `runTest` virtual time with a fake [clock].
 *
 * @param scope the coroutine scope the watcher jobs run on (main-confined in
 *   production; a test scope in tests). All methods must be called on that scope's
 *   thread — this class is not internally synchronized (mirrors `@MainActor`).
 * @param clock wall-clock time in milliseconds; injectable so tests control it.
 */
internal class DeadlineScheduler(
    private val scope: CoroutineScope,
    private val clock: () -> Long = System::currentTimeMillis,
) {
    /**
     * Fired when a deadline expires. `reason` is `"timeout"` (timer fired live)
     * or `"appBackgrounded"` (found past-due while foregrounding).
     */
    var onExpire: ((id: String, reason: String) -> Unit)? = null

    /** Absolute wall-clock deadlines (ms). Survive backgrounding. */
    private val deadlines = HashMap<String, Long>()
    private val jobs = HashMap<String, Job>()

    /** Banked remaining time (ms) for toasts paused mid-interaction (touch-down). */
    private val pausedRemaining = HashMap<String, Long>()
    private var backgrounded = false

    /**
     * Arms (or re-arms) the auto-dismiss for [id]. A null [durationMs] disarms the
     * timer. A fresh arm supersedes any banked pause.
     */
    fun arm(id: String, durationMs: Long?) {
        cancelJob(id)
        pausedRemaining.remove(id)
        if (durationMs == null) {
            deadlines.remove(id)
            return
        }
        val deadline = clock() + durationMs
        deadlines[id] = deadline
        if (!backgrounded) schedule(id, deadline)
    }

    /** Cancels everything known about [id] (teardown, async-action spinner). */
    fun disarm(id: String) {
        cancelJob(id)
        deadlines.remove(id)
        pausedRemaining.remove(id)
    }

    /**
     * Pauses [id]'s auto-dismiss while the user is touching it: banks the
     * remaining time and clears the wall-clock deadline so neither the timer nor a
     * background/foreground cycle can fire mid-interaction. No-op when there is no
     * live deadline (persistent / loading toasts, or an already-paused toast).
     */
    fun pause(id: String) {
        val deadline = deadlines[id] ?: return
        val remaining = deadline - clock()
        if (remaining <= 0) return
        pausedRemaining[id] = remaining
        cancelJob(id)
        deadlines.remove(id)
    }

    /** Resumes a paused [id] with its banked remaining time. No-op if not paused. */
    fun resume(id: String) {
        val remaining = pausedRemaining.remove(id) ?: return
        val deadline = clock() + remaining
        deadlines[id] = deadline
        if (!backgrounded) schedule(id, deadline)
    }

    /** Hot restart / flush: drop all timing state. */
    fun disarmAll() {
        for (job in jobs.values) job.cancel()
        jobs.clear()
        deadlines.clear()
        pausedRemaining.clear()
    }

    // --- App lifecycle ---

    /**
     * Cancels the watcher jobs but keeps the wall-clock deadlines — they are
     * re-evaluated against real time on foreground.
     */
    fun appDidEnterBackground() {
        backgrounded = true
        for (job in jobs.values) job.cancel()
        jobs.clear()
    }

    /**
     * Sweeps the stored deadlines: past-due ones expire immediately (reason
     * `"appBackgrounded"`), live ones get fresh watcher jobs.
     */
    fun appWillEnterForeground() {
        backgrounded = false
        val now = clock()
        // Snapshot: onExpire may mutate `deadlines` (teardown disarms).
        val snapshot = deadlines.toList()
        for ((id, deadline) in snapshot) {
            if (deadline <= now) {
                deadlines.remove(id)
                onExpire?.invoke(id, "appBackgrounded")
            } else {
                schedule(id, deadline)
            }
        }
    }

    // --- Internals ---

    private fun schedule(id: String, fireAt: Long) {
        jobs[id]?.cancel()
        // Capture the delay interval synchronously (against the current clock)
        // rather than inside the coroutine: with a lazily-started test dispatcher
        // the body would otherwise read the clock only after virtual time has
        // already advanced, collapsing the interval.
        val interval = (fireAt - clock()).coerceAtLeast(0)
        jobs[id] = scope.launch {
            delay(interval)
            // Guard against a stale fire: the job may have been cancelled (disarm /
            // background) or the app backgrounded between wake-up and this check.
            if (!isActive || backgrounded) return@launch
            deadlines.remove(id)
            onExpire?.invoke(id, "timeout")
        }
    }

    private fun cancelJob(id: String) {
        jobs.remove(id)?.cancel()
    }
}
