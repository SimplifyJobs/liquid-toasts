package com.rehmatsg.liquid_toasts

import android.graphics.RectF
import androidx.compose.runtime.MutableIntState
import androidx.compose.runtime.MutableState
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

/** App-provided minimum screen-edge insets in logical dp. */
internal data class ToastSafeArea(
    val top: Float = 0f,
    val left: Float = 0f,
    val bottom: Float = 0f,
    val right: Float = 0f,
)

/**
 * The single source of truth for the toast stack, ported from `ToastManager.swift`.
 * Owns the queue, replace-by-[ToastModel.groupKey], per-position `maxVisible`
 * enforcement, exactly-once teardown, and emits lifecycle events back to the
 * plugin via [onEvent]. Auto-dismiss timing lives in [DeadlineScheduler].
 *
 * Main-thread confined (Flutter invokes the plugin handlers on the main thread) —
 * this class is not internally synchronized. It holds Compose *runtime* state
 * only (no Compose-UI imports), so it unit-tests on the JVM by reading `.value`.
 *
 * @param scope main-confined scope for the scheduler's watcher jobs and image
 *   decodes.
 * @param clock wall-clock ms, injectable for tests (event `tsMs` + deadlines).
 * @param decodeImage off-main decode hook (the wired implementation owns its own
 *   background dispatch — see [ToastImageDecoder]). Injectable so tests stub it
 *   and stay UI-free. Returns the decoded pixels (an Android `Bitmap`) or null.
 */
internal class ToastManager(
    private val scope: CoroutineScope,
    private val clock: () -> Long = System::currentTimeMillis,
    private val decodeImage: (suspend (ByteArray) -> Any?)? = null,
) {
    /**
     * The one Compose input: the stack itself. Everything the render tree needs
     * lives on the models (including [ToastModel.isActionBusy]), so a change to
     * one toast invalidates the container once and per-row equality gating keeps
     * the other rows cheap.
     */
    val toasts: MutableState<List<ToastModel>> = mutableStateOf(emptyList())

    /**
     * Bumped exactly when the set of toast ids changes (present / teardown /
     * flush) — the container's animation token. Content morphs keep the
     * generation. iOS uses a plain `var` read inside `.animation(value:)`; Compose
     * has no container-level `.animation(value:)`, so this is an observable
     * [MutableIntState] the container keys its transition off — a justified
     * deviation from the Swift plain-var.
     */
    val stackGeneration: MutableIntState = mutableIntStateOf(0)

    /**
     * Frames (window coordinates) of the interactive toasts, fed by the UI layer
     * and read ONLY imperatively by the overlay host's hit-test. Deliberately a
     * plain map (NOT Compose state): it updates on every animation frame of a drag
     * or spring, and no composable depends on it.
     */
    val frames: MutableMap<String, RectF> = HashMap()

    /** Max toasts shown per position; the oldest is dismissed when exceeded. */
    var maxVisible: Int = 5
    var maxQueue: Int = 8
    var dropOldest: Boolean = true

    /** Minimum safe area supplied by Dart; observed directly by the container. */
    val customSafeArea: MutableState<ToastSafeArea> = mutableStateOf(ToastSafeArea())

    /** Emits a wire-ready event payload to the plugin's event sink. */
    var onEvent: ((Map<String, Any?>) -> Unit)? = null

    /** Fires a haptic for the toast's [ToastHapticKind] (wired by the UI/host layer). */
    var onHaptic: ((ToastHapticKind) -> Unit)? = null

    private val scheduler = DeadlineScheduler(scope, clock)

    /**
     * Guards stale async image decodes: each present/update with bytes bumps the
     * toast's generation, and a decode only attaches if it still matches.
     */
    private val imageGeneration = HashMap<String, Int>()

    init {
        // The teardown guard preserves exactly-once if a stale expiry races a
        // manual dismissal.
        scheduler.onExpire = { id, reason -> teardown(id, reason) }
    }

    private var stack: List<ToastModel>
        get() = toasts.value
        set(value) {
            toasts.value = value
        }

    // --- Present / update / dismiss ---

    fun present(model: ToastModel, imageData: ByteArray? = null) {
        // Replace-by-groupKey: morph an existing toast instead of stacking a dup.
        val key = model.groupKey
        if (key != null) {
            val index = stack.indexOfFirst { it.groupKey == key }
            if (index >= 0) {
                val existing = stack[index]
                val oldId = existing.id
                scheduler.disarm(oldId)
                frames.remove(oldId)
                imageGeneration.remove(oldId)
                var incoming = model
                if (imageData != null) {
                    val preserved = existing.image
                    // Keep the old avatar up until the fresh decode lands (no flash).
                    if (preserved != null) incoming = incoming.copy(image = preserved)
                }
                // Re-show of a group whose text is unchanged: shake the existing
                // toast in place instead of exit+enter. Reusing the row identity
                // avoids the re-entrance; adopting the incoming id keeps the newest
                // handle in control of the (same) toast, like a content morph.
                val textUnchanged = existing.title == incoming.title && existing.message == incoming.message
                if (textUnchanged) {
                    incoming = incoming.copy(
                        identity = existing.rowKey,
                        shakeToken = existing.shakeToken + 1,
                        hasEntered = existing.hasEntered,
                    )
                    // No generation bump: the row-key set is unchanged, so nothing
                    // structural animates — only the row's one-shot shake plays.
                    replaceAt(index, incoming)
                } else {
                    bumpGeneration()
                    replaceAt(index, incoming)
                }
                emitDismissed(oldId, "replaced")
                scheduler.arm(model.id, model.autoDurationMs)
                fireHaptic(model)
                emitShown(model)
                decodeImageIfNeeded(model.id, imageData)
                return
            }
        }

        bumpGeneration()
        stack = stack + model
        enforcePositionLimit(model.position, model.id)
        scheduler.arm(model.id, model.autoDurationMs)
        fireHaptic(model)
        emitShown(model)
        decodeImageIfNeeded(model.id, imageData)
    }

    fun update(id: String, model: ToastModel, imageData: ByteArray? = null): Boolean {
        val index = stack.indexOfFirst { it.id == id }
        if (index < 0) return false
        val preserved = stack[index].image
        // applyingContent also clears isActionBusy — a morph supersedes any
        // in-flight action spinner.
        var updated = stack[index].applyingContent(model)
        if (imageData != null && preserved != null) {
            // Keep the old avatar up until the fresh decode lands (no flash).
            updated = updated.copy(image = preserved)
        }
        // Morph in place: id is unchanged, so stackGeneration stays put and only
        // this row re-renders.
        replaceAt(index, updated)
        scheduler.arm(id, updated.autoDurationMs)
        fireHaptic(updated)
        decodeImageIfNeeded(id, imageData)
        return true
    }

    fun dismiss(id: String, reason: String): Boolean = teardown(id, reason)

    fun dismissAll(reason: String): List<String> {
        val ids = stack.map { it.id }
        for (id in ids) teardown(id, reason)
        return ids
    }

    /** Hot-restart flush: drop everything silently (the old Dart sink is dead). */
    fun flushAll() {
        scheduler.disarmAll()
        imageGeneration.clear()
        bumpGeneration()
        stack = emptyList()
        frames.clear()
    }

    // --- Interaction (called from the UI layer) ---

    fun handleActionTap(id: String) {
        val index = stack.indexOfFirst { it.id == id }
        if (index < 0) return
        val action = stack[index].action ?: return
        emitAction(id, action.actionId)
        if (action.loadingOnPress) {
            // Async action: show the spinner and keep the toast up while the Dart
            // onPressed future runs; the facade dismisses it on completion. Disarm
            // auto-dismiss so the timer can't fire mid-task.
            replaceAt(index, stack[index].copy(isActionBusy = true))
            scheduler.disarm(id)
            return
        }
        if (action.dismissOnPress) teardown(id, "action")
    }

    fun handleBodyTap(id: String) {
        val model = stack.firstOrNull { it.id == id } ?: return
        if (model.hasTap) emitTapped(id)
        if (model.tapToDismiss) teardown(id, "tap")
    }

    fun handleSwipe(id: String) {
        teardown(id, "swipe")
    }

    /**
     * Clears a `loadingOnPress` action's spinner and re-arms the toast's
     * auto-dismiss without removing it — for an async action whose onPressed
     * finished but `dismissOnPress` is false (the toast stays, button idle again).
     */
    fun finishAction(id: String) {
        val index = stack.indexOfFirst { it.id == id }
        if (index < 0 || !stack[index].isActionBusy) return
        val cleared = stack[index].copy(isActionBusy = false)
        replaceAt(index, cleared)
        scheduler.arm(id, cleared.autoDurationMs)
    }

    /**
     * Marks a toast's entrance transition as played, so a config-change reinstall
     * (the overlay is torn down and rebuilt while the manager state survives) does
     * not re-run the entrance for an already-visible toast. Plain assignment — the
     * id set is unchanged, so no container animation fires and only this row
     * re-renders (the flag is otherwise inert in equality).
     */
    fun markEntered(id: String) {
        val index = stack.indexOfFirst { it.id == id }
        if (index < 0 || stack[index].hasEntered) return
        replaceAt(index, stack[index].copy(hasEntered = true))
    }

    /** Pauses a toast's auto-dismiss while the user is touching it. */
    fun pauseAutoDismiss(id: String) {
        if (stack.any { it.id == id }) scheduler.pause(id)
    }

    /** Resumes a paused toast's auto-dismiss with its banked remaining time. */
    fun resumeAutoDismiss(id: String) {
        if (stack.any { it.id == id }) scheduler.resume(id)
    }

    // --- App lifecycle ---

    fun appDidEnterBackground() = scheduler.appDidEnterBackground()
    fun appWillEnterForeground() = scheduler.appWillEnterForeground()

    // --- Teardown (exactly once) ---

    private fun teardown(id: String, reason: String): Boolean {
        val index = stack.indexOfFirst { it.id == id }
        if (index < 0) return false
        scheduler.disarm(id)
        imageGeneration.remove(id)
        bumpGeneration()
        stack = stack.toMutableList().also { it.removeAt(index) }
        frames.remove(id)
        emitDismissed(id, reason)
        return true
    }

    // --- Async image decode ---

    /**
     * Decodes image bytes off the main thread and attaches the pixels to the
     * (still-live, still-current) toast. The reserved slot ([ToastModel.expectsImage])
     * keeps the layout stable while this runs; on decode failure the slot collapses.
     */
    private fun decodeImageIfNeeded(id: String, data: ByteArray?) {
        if (data == null) return
        val decoder = decodeImage ?: return
        val generation = (imageGeneration[id] ?: 0) + 1
        imageGeneration[id] = generation
        scope.launch {
            // The decoder owns its own background dispatch; we resume on this
            // (main-confined) scope to touch the state guarded by generation.
            val pixels = decoder(data)
            attachImage(id, generation, pixels)
        }
    }

    private fun attachImage(id: String, generation: Int, pixels: Any?) {
        if (imageGeneration[id] != generation) return
        val index = stack.indexOfFirst { it.id == id }
        if (index < 0) return
        if (pixels != null) {
            // Plain assignment: the id set is unchanged (generation untouched), so
            // no container animation fires — the pixels appear in the reserved slot.
            replaceAt(index, stack[index].copy(image = ToastImage(pixels)))
        } else {
            // Undecodable bytes: collapse the reserved slot.
            replaceAt(index, stack[index].copy(expectsImage = false))
        }
    }

    /**
     * Keeps at most [maxVisible] toasts per position, dismissing victims with
     * reason `"replaced"`.
     *
     * Only **auto-dismiss** toasts are eligible: a persistent or loading toast
     * has no deadline ([ToastModel.autoDurationMs] is null) and is
     * caller-/promise-owned, so it is never force-dismissed by overflow. When a
     * position fills with such toasts the stack is allowed to **exceed**
     * [maxVisible] (a soft cap) rather than reap one the caller is still
     * managing. The just-presented [incomingId] is likewise never evicted under
     * [dropOldest] — it was explicitly requested now, so it shows even if that
     * means a soft overflow.
     */
    private fun enforcePositionLimit(position: ToastPositionModel, incomingId: String) {
        val inPosition = stack.filter { it.position == position }
        val overflow = inPosition.size - maxVisible
        if (overflow <= 0) return
        // Persistent / loading toasts (no deadline) are exempt from eviction.
        val evictable = inPosition.filter { it.autoDurationMs != null }
        val victims = if (dropOldest) {
            evictable.filter { it.id != incomingId }.take(overflow) // oldest first, keep incoming
        } else {
            evictable.takeLast(overflow) // newest — rejects the incoming transient
        }
        for (victim in victims) teardown(victim.id, "replaced")
    }

    // --- List mutation helpers (each produces a fresh list so Compose sees the change) ---

    private fun replaceAt(index: Int, model: ToastModel) {
        stack = stack.toMutableList().also { it[index] = model }
    }

    private fun bumpGeneration() {
        stackGeneration.intValue += 1
    }

    // --- Events / haptics ---

    private fun emitShown(model: ToastModel) {
        val index = stack.indexOfFirst { it.id == model.id }.coerceAtLeast(0)
        onEvent?.invoke(mapOf("event" to "shown", "id" to model.id, "stackIndex" to index, "tsMs" to clock()))
    }

    private fun emitDismissed(id: String, reason: String) {
        onEvent?.invoke(mapOf("event" to "dismissed", "id" to id, "reason" to reason, "tsMs" to clock()))
    }

    private fun emitAction(id: String, actionId: String) {
        onEvent?.invoke(mapOf("event" to "actionTapped", "id" to id, "actionId" to actionId, "tsMs" to clock()))
    }

    private fun emitTapped(id: String) {
        onEvent?.invoke(mapOf("event" to "tapped", "id" to id, "tsMs" to clock()))
    }

    private fun fireHaptic(model: ToastModel) {
        if (model.haptic != ToastHapticKind.None) onHaptic?.invoke(model.haptic)
    }
}
