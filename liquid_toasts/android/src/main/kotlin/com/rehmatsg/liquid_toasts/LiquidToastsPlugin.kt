package com.rehmatsg.liquid_toasts

import android.content.Context
import android.os.Build
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.ProcessLifecycleOwner
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

/**
 * The Flutter bridge — the Android analog of `LiquidToastsPlugin.swift`. Decodes
 * method-channel arguments into [ToastModel]s, drives the [ToastManager], and
 * streams lifecycle events back over the event channel. Flutter invokes channel
 * handlers on the main thread, so UI is touched directly.
 *
 * State ownership:
 *  - a [ToastManager] + its embedded [DeadlineScheduler] (wired via `onExpire`);
 *  - a main-confined [CoroutineScope] (SupervisorJob + Main.immediate), cancelled
 *    on engine detach;
 *  - a [ProcessLifecycleOwner] observer mapping ON_STOP/ON_START to the manager's
 *    background/foreground sweep (registered at attach, removed at detach);
 *  - an [OverlayHost] installed eagerly on activity attach (so the first toast
 *    gets its entrance) and rebuilt across configuration changes while the
 *    manager state survives.
 *
 * Wire ack shapes and error codes match iOS exactly (see `LiquidToastsPlugin.swift`).
 */
class LiquidToastsPlugin :
    FlutterPlugin,
    ActivityAware,
    MethodCallHandler,
    EventChannel.StreamHandler {

    private lateinit var channel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null

    private var appContext: Context? = null
    private var scope: CoroutineScope? = null
    private var manager: ToastManager? = null
    private var overlay: OverlayHost? = null

    private val lifecycleObserver = object : DefaultLifecycleObserver {
        override fun onStart(owner: LifecycleOwner) {
            manager?.appWillEnterForeground()
        }

        override fun onStop(owner: LifecycleOwner) {
            manager?.appDidEnterBackground()
        }
    }

    // --- FlutterPlugin ---

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "liquid_toasts")
        channel.setMethodCallHandler(this)
        eventChannel = EventChannel(binding.binaryMessenger, "liquid_toasts/events")
        eventChannel.setStreamHandler(this)

        val newScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
        scope = newScope
        val newManager = ToastManager(
            scope = newScope,
            decodeImage = { bytes ->
                val density = appContext?.resources?.displayMetrics?.density ?: 1f
                ToastImageDecoder.decode(bytes, density)
            },
        )
        newManager.onEvent = { payload ->
            newScope.launch { eventSink?.success(payload) }
        }
        newManager.onHaptic = { kind -> overlay?.performHaptic(kind) }
        manager = newManager

        ProcessLifecycleOwner.get().lifecycle.addObserver(lifecycleObserver)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        ProcessLifecycleOwner.get().lifecycle.removeObserver(lifecycleObserver)
        overlay?.teardown()
        overlay = null
        manager = null
        scope?.cancel()
        scope = null
        appContext = null
    }

    // --- ActivityAware ---

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        installOverlay(binding)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        // Keep the manager state; rebuild the overlay on reattach. Already-shown
        // toasts skip their entrance via ToastModel.hasEntered.
        overlay?.teardown()
        overlay = null
        currentActivity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        installOverlay(binding)
    }

    override fun onDetachedFromActivity() {
        overlay?.teardown()
        overlay = null
        currentActivity = null
    }

    private fun installOverlay(binding: ActivityPluginBinding) {
        val mgr = manager ?: return
        val host = OverlayHost(binding.activity, mgr)
        overlay = host
        currentActivity = binding.activity
        // Eager install so the first toast animates in.
        host.install()
    }

    // --- MethodCallHandler ---

    override fun onMethodCall(call: MethodCall, result: Result) {
        // getPlatformVersion is answerable without any attached engine/activity
        // (keeps the bare-instance unit test green); everything else needs state.
        if (call.method == "getPlatformVersion") {
            result.success("Android ${Build.VERSION.RELEASE}")
            return
        }

        val manager = manager
        if (manager == null) {
            result.error("NOT_ATTACHED", "Plugin not attached to an engine", null)
            return
        }

        @Suppress("UNCHECKED_CAST")
        val args = call.arguments as? Map<String, Any?>

        when (call.method) {
            "handshake" -> {
                // The Dart session prefix is reserved wire data — native flushes
                // unconditionally on every handshake (fresh isolate = fresh UI).
                manager.flushAll()
                overlay?.install()
                result.success(null)
            }

            "configure" -> {
                args?.optInt("maxVisible")?.let { manager.maxVisible = maxOf(1, it) }
                args?.optInt("maxQueue")?.let { manager.maxQueue = maxOf(1, it) }
                (args?.get("dropPolicy") as? String)?.let { manager.dropOldest = it != "dropNewest" }
                args?.optMap("safeArea")?.let { safeArea ->
                    manager.customSafeArea.value = ToastSafeArea(
                        top = maxOf(0.0, safeArea.optDouble("top") ?: 0.0).toFloat(),
                        left = maxOf(0.0, safeArea.optDouble("left") ?: 0.0).toFloat(),
                        bottom = maxOf(0.0, safeArea.optDouble("bottom") ?: 0.0).toFloat(),
                        right = maxOf(0.0, safeArea.optDouble("right") ?: 0.0).toFloat(),
                    )
                }
                // defaultGlass is decoded-and-ignored (exact iOS parity).
                result.success(null)
            }

            "show" -> {
                overlay?.install()
                val id = args?.optString("id")
                val model = if (id != null && args != null) ToastModel.fromWire(args, id) else null
                if (model == null || args == null) {
                    result.error("INVALID_ARGS", "show: missing id/message", null)
                    return
                }
                manager.present(model, args.byteArray("image"))
                result.success(
                    mapOf(
                        "id" to model.id,
                        "accepted" to true,
                        "capability" to mapOf(
                            "dynamicIslandOriginUsed" to false,
                            "glassMode" to glassMode(),
                        ),
                    ),
                )
            }

            "update" -> {
                val id = args?.optString("id")
                val model = if (id != null) ToastModel.fromWire(args, id) else null
                if (id == null || model == null) {
                    result.error("INVALID_ARGS", "update: missing id/message", null)
                    return
                }
                val applied = manager.update(id, model, args.byteArray("image"))
                val res = mutableMapOf<String, Any?>("id" to id, "applied" to applied)
                if (!applied) res["reason"] = "unknown_id"
                result.success(res)
            }

            "dismiss" -> {
                val id = args?.optString("id")
                if (id == null) {
                    result.error("INVALID_ARGS", "dismiss: missing id", null)
                    return
                }
                val ok = manager.dismiss(id, "manual")
                val res = mutableMapOf<String, Any?>("id" to id, "dismissed" to ok)
                if (!ok) res["reason"] = "unknown_id"
                result.success(res)
            }

            "dismissAll" -> {
                val reason = (args?.get("reason") as? String) ?: "dismissAll"
                result.success(mapOf("dismissedIds" to manager.dismissAll(reason)))
            }

            "finishAction" -> {
                args?.optString("id")?.let { manager.finishAction(it) }
                result.success(null)
            }

            "debugTriggerAction" -> {
                // Simulates an action-button tap (drives the spinner + lifecycle);
                // used by the example's async-action demo.
                args?.optString("id")?.let { manager.handleActionTap(it) }
                result.success(null)
            }

            "queryGeometry" -> {
                val snapshot = Geometry.snapshot(currentActivity).toMutableMap()
                snapshot["glassMode"] = glassMode()
                result.success(snapshot)
            }

            else -> result.notImplemented()
        }
    }

    // --- EventChannel.StreamHandler ---

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    // --- Helpers ---

    // Android renders an opaque surface (no Liquid Glass / no blur); nothing on
    // the Dart side reads this — it's an honest capability string.
    private fun glassMode(): String = "opaque"

    /** The current activity, if attached (for the geometry snapshot). */
    private var currentActivity: android.app.Activity? = null
}
