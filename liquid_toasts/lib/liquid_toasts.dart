import 'package:flutter/foundation.dart';

import 'src/liquid_toasts_config.dart';
import 'src/loading_toast.dart';
import 'src/semantic_defaults.dart';
import 'src/toast.dart';
import 'src/toast_action.dart';
import 'src/toast_engine.dart';
import 'src/toast_event.dart';
import 'src/toast_handle.dart';
import 'src/toast_position.dart';
import 'src/toast_style.dart';
import 'src/toaster.dart';

export 'src/liquid_toasts_config.dart';
export 'src/loading_toast.dart';
export 'src/toast.dart';
export 'src/toast_action.dart';
export 'src/toast_event.dart';
export 'src/toast_handle.dart' show ToastHandle;
export 'src/toast_position.dart';
export 'src/toast_style.dart';
export 'src/toaster.dart' show Toaster;

/// The global toaster — the package's primary API:
///
/// ```dart
/// toast.success('Saved to favorites');
/// toast('Plain message');
/// final t = toast.show('Uploading…', duration: null, progress: 0);
/// t.update(progress: 0.6);
/// final user = await toast.promise(api.signIn(), loading: 'Signing in…');
/// ```
///
/// If the name collides with one of your identifiers,
/// `import 'package:liquid_toasts/liquid_toasts.dart' hide toast;` and use
/// [Toaster.instance] instead.
const Toaster toast = Toaster.instance;

/// The legacy static facade, superseded by the global [toast] object.
///
/// Every member delegates to the same engine as [toast] and keeps its original
/// contract (`show` resolves after the native ack), so mixing old and new call
/// sites is safe during migration. Removed in 1.0.
///
/// ```dart
/// LiquidToasts.success('Saved');   // before
/// toast.success('Saved');          // after
/// ```
class LiquidToasts {
  LiquidToasts._();

  static ToastEngine get _engine => ToastEngine.instance;

  /// Optional global hook mapping a thrown error to a user-safe message, used by
  /// [showLoading] when no per-call `onError` builder is supplied. Keeps
  /// `error.toString()` from leaking internals into a user-facing toast.
  @Deprecated('Use toast.errorMessageResolver instead. Removed in 1.0.')
  static String Function(Object error)? get errorMessageResolver =>
      _engine.errorMessageResolver;
  @Deprecated('Use toast.errorMessageResolver instead. Removed in 1.0.')
  static set errorMessageResolver(String Function(Object error)? resolver) =>
      _engine.errorMessageResolver = resolver;

  /// Number of toasts currently tracked (visible + queued).
  @Deprecated('Use toast.activeCount instead. Removed in 1.0.')
  static int get activeCount => _engine.activeCount;

  /// Ids of toasts currently tracked.
  @Deprecated('Use toast.activeIds instead. Removed in 1.0.')
  static List<String> get activeIds => _engine.activeIds;

  /// Sets app-wide defaults (used by the convenience constructors) and pushes
  /// stack/queue configuration to native.
  @Deprecated('Use toast.setDefaults(...) instead. Removed in 1.0.')
  static Future<void> setDefaults(LiquidToastsConfig config) =>
      _engine.setDefaults(config);

  // ---------------------------------------------------------------------------
  // Core
  // ---------------------------------------------------------------------------

  /// Shows [toast]. Resolves to a [ToastHandle] for later update/dismiss and to
  /// `await` its dismissal.
  @Deprecated('Use toast.raw(Toast(...)) — or toast.show(message, ...) for '
      'message-first calls. Both return the handle synchronously. '
      'Removed in 1.0.')
  static Future<ToastHandle> show(Toast toast) => _show(toast);

  /// Convenience: a success toast.
  @Deprecated('Use toast.success(...) instead (returns the handle '
      'synchronously). Removed in 1.0.')
  static Future<ToastHandle> success(
    String message, {
    String? title,
    String? icon,
    ToastPosition? position,
    Duration? duration,
    ToastAction? action,
    VoidCallback? onTap,
    bool tapToDismiss = true,
    ToastStyleOverride? style,
    String? groupKey,
    ToastHaptic? haptic,
    bool useDynamicIslandOrigin = true,
  }) =>
      _show(Toast.success(
        message: message,
        title: title,
        icon: icon,
        position: position,
        duration: duration ??
            _engine.config.defaultDuration ??
            SemanticDefaults.successDuration,
        action: action,
        onTap: onTap,
        tapToDismiss: tapToDismiss,
        style: style,
        groupKey: groupKey,
        haptic: haptic,
        useDynamicIslandOrigin: useDynamicIslandOrigin,
      ));

  /// Convenience: an error toast.
  @Deprecated('Use toast.error(...) instead (returns the handle '
      'synchronously). Removed in 1.0.')
  static Future<ToastHandle> error(
    String message, {
    String? title,
    String? icon,
    ToastPosition? position,
    Duration? duration,
    ToastAction? action,
    VoidCallback? onTap,
    bool tapToDismiss = true,
    ToastStyleOverride? style,
    String? groupKey,
    ToastHaptic? haptic,
    bool useDynamicIslandOrigin = true,
  }) =>
      _show(Toast.error(
        message: message,
        title: title,
        icon: icon,
        position: position,
        duration: duration ??
            _engine.config.defaultDuration ??
            SemanticDefaults.errorDuration,
        action: action,
        onTap: onTap,
        tapToDismiss: tapToDismiss,
        style: style,
        groupKey: groupKey,
        haptic: haptic,
        useDynamicIslandOrigin: useDynamicIslandOrigin,
      ));

  /// Convenience: a warning toast.
  @Deprecated('Use toast.warning(...) instead (returns the handle '
      'synchronously). Removed in 1.0.')
  static Future<ToastHandle> warning(
    String message, {
    String? title,
    String? icon,
    ToastPosition? position,
    Duration? duration,
    ToastAction? action,
    VoidCallback? onTap,
    bool tapToDismiss = true,
    ToastStyleOverride? style,
    String? groupKey,
    ToastHaptic? haptic,
    bool useDynamicIslandOrigin = true,
  }) =>
      _show(Toast.warning(
        message: message,
        title: title,
        icon: icon,
        position: position,
        duration: duration ??
            _engine.config.defaultDuration ??
            SemanticDefaults.warningDuration,
        action: action,
        onTap: onTap,
        tapToDismiss: tapToDismiss,
        style: style,
        groupKey: groupKey,
        haptic: haptic,
        useDynamicIslandOrigin: useDynamicIslandOrigin,
      ));

  /// Convenience: an info toast.
  @Deprecated('Use toast.info(...) instead (returns the handle '
      'synchronously). Removed in 1.0.')
  static Future<ToastHandle> info(
    String message, {
    String? title,
    String? icon,
    ToastPosition? position,
    Duration? duration,
    ToastAction? action,
    VoidCallback? onTap,
    bool tapToDismiss = true,
    ToastStyleOverride? style,
    String? groupKey,
    ToastHaptic? haptic,
    bool useDynamicIslandOrigin = true,
  }) =>
      _show(Toast.info(
        message: message,
        title: title,
        icon: icon,
        position: position,
        duration: duration ??
            _engine.config.defaultDuration ??
            SemanticDefaults.infoDuration,
        action: action,
        onTap: onTap,
        tapToDismiss: tapToDismiss,
        style: style,
        groupKey: groupKey,
        haptic: haptic,
        useDynamicIslandOrigin: useDynamicIslandOrigin,
      ));

  /// Ties [future] to a loading toast: a spinner while it runs, then a success
  /// or error toast.
  ///
  /// **Returns the future's value** (or rethrows its error) so the caller owns
  /// the outcome — dismissing the toast never swallows the result. The visual is
  /// best-effort: if the toast was dismissed mid-flight, the update is skipped
  /// but the value/error is still delivered.
  ///
  /// ```dart
  /// final user = await LiquidToasts.showLoading(
  ///   api.signIn(email, password),
  ///   config: const LoadingToast(
  ///     loadingMessage: 'Signing in…',
  ///     successMessage: 'Welcome back!',
  ///   ),
  ///   onSuccess: (u) => Toast.success(message: 'Hi ${u.name}!'),
  /// );
  /// ```
  @Deprecated('Use toast.promise(future, loading:, success:, error:) instead. '
      'Removed in 1.0.')
  static Future<T> showLoading<T>(
    Future<T> future, {
    required LoadingToast config,
    Toast Function(T value)? onSuccess,
    Toast Function(Object error, StackTrace stack)? onError,
  }) =>
      _engine.promiseWith<T>(
        future,
        loading: config.buildLoading(),
        success: (value) => onSuccess?.call(value) ?? config.buildSuccess(),
        error: (e, st) =>
            onError?.call(e, st) ??
            config.buildError(e,
                resolvedMessage: _engine.errorMessageResolver?.call(e)),
      );

  /// Dismisses toast [id]. Prefer [ToastHandle.dismiss] when you hold a handle.
  @Deprecated('Use toast.dismiss(id) instead. Removed in 1.0.')
  static Future<void> dismiss(String id) => _engine.dismiss(id);

  /// Dismisses every toast.
  @Deprecated('Use toast.dismissAll() instead. Removed in 1.0.')
  static Future<void> dismissAll() => _engine.dismissAll();

  /// Advisory device geometry / capability snapshot.
  @Deprecated('Use toast.queryGeometry() instead. Removed in 1.0.')
  static Future<Map<String, dynamic>> queryGeometry() =>
      _engine.queryGeometry();

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  /// Shows via the engine, then waits for the platform call to land —
  /// preserving this facade's original contract (`show` resolved after the
  /// native ack).
  static Future<ToastHandle> _show(Toast toast) async {
    final handle = _engine.show(toast);
    await _engine.settle(handle.id);
    return handle;
  }

  /// Resets all static state. Test-only — lets each test start clean.
  @Deprecated('Use toast.debugReset() instead. Removed in 1.0.')
  @visibleForTesting
  static Future<void> debugReset() => _engine.debugReset();

  /// Emits a native event into the engine's router. Test-only.
  @Deprecated('Use toast.debugEmit(event) instead. Removed in 1.0.')
  @visibleForTesting
  static void debugEmit(ToastEvent event) => _engine.debugEmit(event);

  /// Simulates an action-button tap on the live toast [id] (drives the native
  /// loading spinner + lifecycle for a `loadingOnPress` action). For tests and
  /// the example's async-action demo, which can't synthesize a real touch.
  @Deprecated('Use toast.debugTriggerAction(id) instead. Removed in 1.0.')
  @visibleForTesting
  static Future<void> debugTriggerAction(String id) =>
      _engine.debugTriggerAction(id);
}
