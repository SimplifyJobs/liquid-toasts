package com.rehmatsg.liquid_toasts

import android.annotation.SuppressLint
import android.app.Activity
import android.content.Context
import android.graphics.Color
import android.view.MotionEvent
import android.view.ViewGroup
import android.view.WindowInsets
import android.widget.FrameLayout
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.ComposeView
import androidx.compose.ui.platform.ViewCompositionStrategy
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry
import androidx.lifecycle.ViewModelStore
import androidx.lifecycle.ViewModelStoreOwner
import androidx.lifecycle.findViewTreeLifecycleOwner
import androidx.lifecycle.setViewTreeLifecycleOwner
import androidx.lifecycle.setViewTreeViewModelStoreOwner
import androidx.savedstate.SavedStateRegistry
import androidx.savedstate.SavedStateRegistryController
import androidx.savedstate.SavedStateRegistryOwner
import androidx.savedstate.setViewTreeSavedStateRegistryOwner

/**
 * A transparent [FrameLayout] added above the Flutter content in the same
 * activity window. It only swallows touches that land on an actual toast
 * frame; everything else
 * falls through to the sibling FlutterView. The Android analog of
 * `ToastOverlayHost.swift` + `PassthroughHostView`.
 */
@SuppressLint("ViewConstructor")
internal class OverlayHostView(
    context: Context,
    private val manager: ToastManager,
) : FrameLayout(context) {

    override fun dispatchTouchEvent(ev: MotionEvent): Boolean {
        // On the initial down, hit-test the toast frames (window coordinates). If
        // no toast sits under the point, return false so the touch falls through
        // to the FlutterView. Once a gesture starts on a toast, keep dispatching
        // it here (the down decided ownership).
        if (ev.actionMasked == MotionEvent.ACTION_DOWN) {
            val loc = IntArray(2)
            getLocationOnScreen(loc)
            val x = ev.x + loc[0]
            val y = ev.y + loc[1]
            val onToast = manager.frames.values.any { it.contains(x, y) }
            if (!onToast) return false
        }
        return super.dispatchTouchEvent(ev)
    }
}

/**
 * Installs and owns the overlay for one activity. Created per plugin activity
 * attachment; on a configuration change the view is torn down and rebuilt while
 * the [ToastManager] (engine-scoped) survives, so already-shown toasts skip
 * their entrance ([ToastModel.hasEntered]).
 *
 * `FlutterActivity` is a `LifecycleOwner` but NOT a `SavedStateRegistryOwner`,
 * which Compose requires — so this host installs its own combined owner
 * ([lifecycleOwner]) via the view-tree setters before `setContent`, driving that
 * lifecycle itself.
 */
internal class OverlayHost(
    private val activity: Activity,
    private val manager: ToastManager,
) {
    private var hostView: OverlayHostView? = null
    private var composeView: ComposeView? = null
    private var ownsDecorOwners = false

    private val lifecycleOwner = OverlayLifecycleOwner()

    /** Insets state the container observes (safe area + IME), updated on apply. */
    private var insetsState by mutableStateOf(ToastInsets())
    private var entranceDistanceDp = 16f

    /** Fires the toast's semantic haptic on the overlay's host view. */
    fun performHaptic(kind: ToastHapticKind) {
        hostView?.let { Haptics.perform(it, kind) }
    }

    /** Installs the overlay into the activity decor view (last child, transparent). */
    fun install() {
        if (hostView != null) return
        val decor = activity.window?.decorView as? ViewGroup ?: return

        val host = OverlayHostView(activity, manager)
        host.setBackgroundColor(Color.TRANSPARENT)
        host.layoutParams = FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT,
        )

        lifecycleOwner.onCreate()

        val compose = ComposeView(activity)
        compose.setViewCompositionStrategy(ViewCompositionStrategy.DisposeOnDetachedFromWindow)
        compose.setViewTreeLifecycleOwner(lifecycleOwner)
        compose.setViewTreeSavedStateRegistryOwner(lifecycleOwner)
        compose.setViewTreeViewModelStoreOwner(lifecycleOwner)

        compose.setContent {
            val isDark = isSystemInDarkTheme()
            val density = LocalContext.current.resources.displayMetrics.density
            val deviceWidthDp = host.width / density
            ToastContainer(
                manager = manager,
                insets = insetsState,
                customSafeArea = manager.customSafeArea.value,
                entranceDistanceDp = entranceDistanceDp,
                isDark = isDark,
                animationsEnabled = animatorsEnabled(),
                deviceWidthDp = if (deviceWidthDp > 0) deviceWidthDp else fallbackWidthDp(),
            )
        }

        host.addView(
            compose,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            ),
        )

        host.setOnApplyWindowInsetsListener { _, insets -> applyInsets(insets); insets }
        // Compose's window recomposer resolves its lifecycle from the WINDOW ROOT
        // (`rootView.findViewTreeLifecycleOwner()`), not from the ComposeView's
        // ancestors — and FlutterActivity (a plain Activity, not ComponentActivity)
        // never sets owners on its decor. Install ours there, but never clobber a
        // host app's (add-to-app with an AndroidX activity).
        if (decor.findViewTreeLifecycleOwner() == null) {
            decor.setViewTreeLifecycleOwner(lifecycleOwner)
            decor.setViewTreeSavedStateRegistryOwner(lifecycleOwner)
            decor.setViewTreeViewModelStoreOwner(lifecycleOwner)
            ownsDecorOwners = true
        }
        decor.addView(host)
        host.requestApplyInsets()
        host.post { lifecycleOwner.onResume() }

        hostView = host
        composeView = compose
    }

    /** Keeps the overlay frontmost if the activity later adds sibling views. */
    fun bringToFront() {
        hostView?.bringToFront()
    }

    /** Tears down the overlay (config change / detach); manager state survives. */
    fun teardown() {
        val host = hostView ?: return
        composeView?.disposeComposition()
        lifecycleOwner.onDestroy()
        if (ownsDecorOwners) {
            (activity.window?.decorView)?.let { decor ->
                decor.setViewTreeLifecycleOwner(null)
                decor.setViewTreeSavedStateRegistryOwner(null)
                decor.setViewTreeViewModelStoreOwner(null)
            }
            ownsDecorOwners = false
        }
        (host.parent as? ViewGroup)?.removeView(host)
        hostView = null
        composeView = null
    }

    private fun applyInsets(insets: WindowInsets) {
        val density = activity.resources.displayMetrics.density
        fun px(v: Int) = (v / density).dp
        if (android.os.Build.VERSION.SDK_INT >= 30) {
            val bars = insets.getInsets(
                WindowInsets.Type.systemBars() or WindowInsets.Type.displayCutout(),
            )
            val ime = insets.getInsets(WindowInsets.Type.ime())
            insetsState = ToastInsets(
                top = px(bars.top),
                left = px(bars.left),
                right = px(bars.right),
                bottom = px(bars.bottom),
                ime = px((ime.bottom - bars.bottom).coerceAtLeast(0)),
            )
            entranceDistanceDp = maxOf(16f, bars.top / density * 0.5f)
        } else {
            @Suppress("DEPRECATION")
            insetsState = ToastInsets(
                top = px(insets.systemWindowInsetTop),
                left = px(insets.systemWindowInsetLeft),
                right = px(insets.systemWindowInsetRight),
                bottom = px(insets.systemWindowInsetBottom),
            )
            @Suppress("DEPRECATION")
            entranceDistanceDp = maxOf(16f, insets.systemWindowInsetTop / density * 0.5f)
        }
    }

    private fun fallbackWidthDp(): Float {
        val m = activity.resources.displayMetrics
        return if (m.density > 0) m.widthPixels / m.density else 360f
    }

    /** Reflects the system "Remove animations" accessibility setting. */
    private fun animatorsEnabled(): Boolean = android.animation.ValueAnimator.areAnimatorsEnabled()
}

/**
 * A minimal combined [LifecycleOwner] + [SavedStateRegistryOwner] +
 * [ViewModelStoreOwner] for the overlay's ComposeView. FlutterActivity supplies
 * a Lifecycle but no SavedStateRegistry, which Compose's ComposeView requires;
 * this drives its own lifecycle CREATED→RESUMED on install and DESTROYED on
 * teardown.
 */
private class OverlayLifecycleOwner :
    LifecycleOwner,
    SavedStateRegistryOwner,
    ViewModelStoreOwner {

    private val registry = LifecycleRegistry(this)
    private val savedStateController = SavedStateRegistryController.create(this)
    private val store = ViewModelStore()

    override val lifecycle: Lifecycle get() = registry
    override val savedStateRegistry: SavedStateRegistry get() = savedStateController.savedStateRegistry
    override val viewModelStore: ViewModelStore get() = store

    fun onCreate() {
        savedStateController.performRestore(null)
        registry.currentState = Lifecycle.State.CREATED
    }

    fun onResume() {
        registry.currentState = Lifecycle.State.RESUMED
    }

    fun onDestroy() {
        registry.currentState = Lifecycle.State.DESTROYED
        store.clear()
    }
}
