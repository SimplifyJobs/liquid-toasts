import 'dart:ui' show VoidCallback;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/painting.dart' show ImageProvider;

import 'liquid_toasts_config.dart';
import 'semantic_defaults.dart';
import 'toast.dart';
import 'toast_action.dart';
import 'toast_engine.dart';
import 'toast_event.dart';
import 'toast_handle.dart';
import 'toast_position.dart';
import 'toast_style.dart';

/// Sentinel meaning "the caller omitted `duration`" — distinct from an explicit
/// `null` (which means persistent). Never leaks: it is resolved before a
/// [Toast] is constructed.
const Duration _useDefault = Duration(microseconds: -1);

/// The API behind the global `toast` object — a Sonner-style, context-free
/// toaster whose `show` methods return a [ToastHandle] **synchronously**.
///
/// ```dart
/// toast.success('Saved to favorites');
/// toast('Plain message');
///
/// final user = await toast.promise(
///   api.signIn(email, password),
///   loading: 'Signing in…',
///   success: (u) => 'Welcome back, ${u.name}!',
///   error: 'Sign-in failed',
/// );
///
/// final t = toast.show('Uploading…', duration: null, progress: 0);
/// t.update(progress: 0.6);
/// t.dismiss();
/// ```
///
/// If the top-level `toast` name collides with one of your identifiers,
/// `import 'package:liquid_toasts/liquid_toasts.dart' hide toast;` and use
/// [Toaster.instance].
final class Toaster {
  const Toaster._();

  /// The singleton behind the top-level `toast` constant.
  static const Toaster instance = Toaster._();

  ToastEngine get _engine => ToastEngine.instance;

  // ---------------------------------------------------------------------------
  // Show
  // ---------------------------------------------------------------------------

  /// `toast('message')` — shorthand for [show].
  ToastHandle call(
    String message, {
    String? title,
    String? icon,
    ImageProvider? leadingImage,
    ToastSemantic semantic = ToastSemantic.none,
    ToastStyleOverride? style,
    ToastPosition? position,
    Duration? duration = _useDefault,
    ToastAction? action,
    VoidCallback? onTap,
    bool tapToDismiss = true,
    String? groupKey,
    double? progress,
    ToastProgressStyle progressStyle = ToastProgressStyle.linear,
    ToastHaptic? haptic,
    String? semanticsLabel,
    int? maxLines,
    int? titleMaxLines,
    bool useDynamicIslandOrigin = true,
  }) =>
      _semanticShow(
        semantic,
        message,
        title: title,
        icon: icon,
        leadingImage: leadingImage,
        style: style,
        position: position,
        duration: duration,
        action: action,
        onTap: onTap,
        tapToDismiss: tapToDismiss,
        groupKey: groupKey,
        progress: progress,
        progressStyle: progressStyle,
        haptic: haptic,
        semanticsLabel: semanticsLabel,
        maxLines: maxLines,
        titleMaxLines: titleMaxLines,
        useDynamicIslandOrigin: useDynamicIslandOrigin,
      );

  /// Shows a toast and returns its [ToastHandle] immediately — no `await`
  /// needed. Omitting [duration] uses the app/semantic default; an explicit
  /// `duration: null` makes the toast persistent.
  ToastHandle show(
    String message, {
    String? title,
    String? icon,
    ImageProvider? leadingImage,
    ToastSemantic semantic = ToastSemantic.none,
    ToastStyleOverride? style,
    ToastPosition? position,
    Duration? duration = _useDefault,
    ToastAction? action,
    VoidCallback? onTap,
    bool tapToDismiss = true,
    String? groupKey,
    double? progress,
    ToastProgressStyle progressStyle = ToastProgressStyle.linear,
    ToastHaptic? haptic,
    String? semanticsLabel,
    int? maxLines,
    int? titleMaxLines,
    bool useDynamicIslandOrigin = true,
  }) =>
      _semanticShow(
        semantic,
        message,
        title: title,
        icon: icon,
        leadingImage: leadingImage,
        style: style,
        position: position,
        duration: duration,
        action: action,
        onTap: onTap,
        tapToDismiss: tapToDismiss,
        groupKey: groupKey,
        progress: progress,
        progressStyle: progressStyle,
        haptic: haptic,
        semanticsLabel: semanticsLabel,
        maxLines: maxLines,
        titleMaxLines: titleMaxLines,
        useDynamicIslandOrigin: useDynamicIslandOrigin,
      );

  /// A success toast.
  ToastHandle success(
    String message, {
    String? title,
    String? icon,
    ImageProvider? leadingImage,
    ToastStyleOverride? style,
    ToastPosition? position,
    Duration? duration = _useDefault,
    ToastAction? action,
    VoidCallback? onTap,
    bool tapToDismiss = true,
    String? groupKey,
    double? progress,
    ToastProgressStyle progressStyle = ToastProgressStyle.linear,
    ToastHaptic? haptic,
    String? semanticsLabel,
    int? maxLines,
    int? titleMaxLines,
    bool useDynamicIslandOrigin = true,
  }) =>
      _semanticShow(
        ToastSemantic.success,
        message,
        title: title,
        icon: icon,
        leadingImage: leadingImage,
        style: style,
        position: position,
        duration: duration,
        action: action,
        onTap: onTap,
        tapToDismiss: tapToDismiss,
        groupKey: groupKey,
        progress: progress,
        progressStyle: progressStyle,
        haptic: haptic,
        semanticsLabel: semanticsLabel,
        maxLines: maxLines,
        titleMaxLines: titleMaxLines,
        useDynamicIslandOrigin: useDynamicIslandOrigin,
      );

  /// An error toast (lingers a beat longer by default).
  ToastHandle error(
    String message, {
    String? title,
    String? icon,
    ImageProvider? leadingImage,
    ToastStyleOverride? style,
    ToastPosition? position,
    Duration? duration = _useDefault,
    ToastAction? action,
    VoidCallback? onTap,
    bool tapToDismiss = true,
    String? groupKey,
    double? progress,
    ToastProgressStyle progressStyle = ToastProgressStyle.linear,
    ToastHaptic? haptic,
    String? semanticsLabel,
    int? maxLines,
    int? titleMaxLines,
    bool useDynamicIslandOrigin = true,
  }) =>
      _semanticShow(
        ToastSemantic.error,
        message,
        title: title,
        icon: icon,
        leadingImage: leadingImage,
        style: style,
        position: position,
        duration: duration,
        action: action,
        onTap: onTap,
        tapToDismiss: tapToDismiss,
        groupKey: groupKey,
        progress: progress,
        progressStyle: progressStyle,
        haptic: haptic,
        semanticsLabel: semanticsLabel,
        maxLines: maxLines,
        titleMaxLines: titleMaxLines,
        useDynamicIslandOrigin: useDynamicIslandOrigin,
      );

  /// A warning toast.
  ToastHandle warning(
    String message, {
    String? title,
    String? icon,
    ImageProvider? leadingImage,
    ToastStyleOverride? style,
    ToastPosition? position,
    Duration? duration = _useDefault,
    ToastAction? action,
    VoidCallback? onTap,
    bool tapToDismiss = true,
    String? groupKey,
    double? progress,
    ToastProgressStyle progressStyle = ToastProgressStyle.linear,
    ToastHaptic? haptic,
    String? semanticsLabel,
    int? maxLines,
    int? titleMaxLines,
    bool useDynamicIslandOrigin = true,
  }) =>
      _semanticShow(
        ToastSemantic.warning,
        message,
        title: title,
        icon: icon,
        leadingImage: leadingImage,
        style: style,
        position: position,
        duration: duration,
        action: action,
        onTap: onTap,
        tapToDismiss: tapToDismiss,
        groupKey: groupKey,
        progress: progress,
        progressStyle: progressStyle,
        haptic: haptic,
        semanticsLabel: semanticsLabel,
        maxLines: maxLines,
        titleMaxLines: titleMaxLines,
        useDynamicIslandOrigin: useDynamicIslandOrigin,
      );

  /// An info toast.
  ToastHandle info(
    String message, {
    String? title,
    String? icon,
    ImageProvider? leadingImage,
    ToastStyleOverride? style,
    ToastPosition? position,
    Duration? duration = _useDefault,
    ToastAction? action,
    VoidCallback? onTap,
    bool tapToDismiss = true,
    String? groupKey,
    double? progress,
    ToastProgressStyle progressStyle = ToastProgressStyle.linear,
    ToastHaptic? haptic,
    String? semanticsLabel,
    int? maxLines,
    int? titleMaxLines,
    bool useDynamicIslandOrigin = true,
  }) =>
      _semanticShow(
        ToastSemantic.info,
        message,
        title: title,
        icon: icon,
        leadingImage: leadingImage,
        style: style,
        position: position,
        duration: duration,
        action: action,
        onTap: onTap,
        tapToDismiss: tapToDismiss,
        groupKey: groupKey,
        progress: progress,
        progressStyle: progressStyle,
        haptic: haptic,
        semanticsLabel: semanticsLabel,
        maxLines: maxLines,
        titleMaxLines: titleMaxLines,
        useDynamicIslandOrigin: useDynamicIslandOrigin,
      );

  /// A persistent spinner toast. Morph it later with
  /// [ToastHandle.update]/[ToastHandle.replace] or remove it with
  /// [ToastHandle.dismiss].
  ToastHandle loading(
    String message, {
    String? title,
    String? icon,
    ToastStyleOverride? style,
    ToastPosition? position,
    String? groupKey,
    double? progress,
    ToastProgressStyle progressStyle = ToastProgressStyle.linear,
    String? semanticsLabel,
    int? maxLines,
    int? titleMaxLines,
    bool useDynamicIslandOrigin = true,
  }) =>
      _engine.show(Toast.loading(
        message: message,
        title: title,
        icon: icon,
        style: style,
        position: position,
        groupKey: groupKey,
        progress: progress,
        progressStyle: progressStyle,
        semanticsLabel: semanticsLabel,
        maxLines: maxLines,
        titleMaxLines: titleMaxLines,
        useDynamicIslandOrigin: useDynamicIslandOrigin,
      ));

  /// Full-control escape hatch. Explicit toast values win; omitted position and
  /// line limits inherit the app defaults.
  ToastHandle raw(Toast toast) => _engine.show(toast);

  // ---------------------------------------------------------------------------
  // Promise
  // ---------------------------------------------------------------------------

  /// Ties [future] to a loading toast: a spinner while it runs, then a success
  /// or error toast.
  ///
  /// **Returns the future's value** (or rethrows its error) so the caller owns
  /// the outcome — the visual is best-effort and never swallows the result.
  ///
  /// [loading] is a `String` or [Toast]. [success] is a `String`, [Toast],
  /// `String Function(value)`, or `Toast Function(value)`. [error] is a
  /// `String`, [Toast], `String Function(Object error)`, or
  /// `Toast Function(Object error)`. Anything else throws an [ArgumentError]
  /// immediately (before the future is awaited). When [error] is omitted the
  /// message comes from [errorMessageResolver], falling back to
  /// `error.toString()`.
  Future<T> promise<T>(
    Future<T> future, {
    Object loading = 'Loading…',
    Object? success,
    Object? error,
    ToastPosition? position,
    ToastStyleOverride? style,
    bool useDynamicIslandOrigin = true,
  }) {
    // Specs are validated eagerly so misuse throws at the call site, not
    // after the future completes.
    final loadingToast = switch (loading) {
      final Toast t => t,
      final String s => Toast.loading(
          message: s,
          position: position,
          style: style,
          useDynamicIslandOrigin: useDynamicIslandOrigin,
        ),
      _ => throw ArgumentError.value(
          loading, 'loading', 'must be a String or Toast'),
    };
    final successBuilder = switch (success) {
      null => (T value) => _promisePhase(ToastSemantic.success, 'Done',
          position, style, useDynamicIslandOrigin),
      final Toast t => (T value) => t,
      final String s => (T value) => _promisePhase(
          ToastSemantic.success, s, position, style, useDynamicIslandOrigin),
      final Toast Function(T) f => f,
      final String Function(T) f => (T value) => _promisePhase(
          ToastSemantic.success,
          f(value),
          position,
          style,
          useDynamicIslandOrigin),
      _ => throw ArgumentError.value(success, 'success',
          'must be a String, Toast, String Function(value), or Toast Function(value)'),
    };
    final errorBuilder = switch (error) {
      null => (Object e, StackTrace _) => _promisePhase(
          ToastSemantic.error,
          _engine.errorMessageResolver?.call(e) ?? e.toString(),
          position,
          style,
          useDynamicIslandOrigin),
      final Toast t => (Object e, StackTrace _) => t,
      final String s => (Object e, StackTrace _) => _promisePhase(
          ToastSemantic.error, s, position, style, useDynamicIslandOrigin),
      final Toast Function(Object) f => (Object e, StackTrace _) => f(e),
      final String Function(Object) f => (Object e, StackTrace _) =>
          _promisePhase(ToastSemantic.error, f(e), position, style,
              useDynamicIslandOrigin),
      _ => throw ArgumentError.value(error, 'error',
          'must be a String, Toast, String Function(error), or Toast Function(error)'),
    };
    return _engine.promiseWith<T>(
      future,
      loading: loadingToast,
      success: successBuilder,
      error: errorBuilder,
    );
  }

  // ---------------------------------------------------------------------------
  // Management
  // ---------------------------------------------------------------------------

  /// Dismisses toast [id]. Prefer [ToastHandle.dismiss] when you hold a handle.
  Future<void> dismiss(String id) => _engine.dismiss(id);

  /// Dismisses every toast.
  Future<void> dismissAll() => _engine.dismissAll();

  /// Sets app-wide defaults (position, duration, stack/queue limits) and
  /// pushes them to native.
  Future<void> setDefaults(LiquidToastsConfig config) =>
      _engine.setDefaults(config);

  /// Optional global hook mapping a thrown error to a user-safe message, used
  /// by [promise] when no per-call `error` spec is supplied. Keeps
  /// `error.toString()` from leaking internals into a user-facing toast.
  String Function(Object error)? get errorMessageResolver =>
      _engine.errorMessageResolver;
  set errorMessageResolver(String Function(Object error)? resolver) =>
      _engine.errorMessageResolver = resolver;

  /// Number of toasts currently tracked (visible + queued).
  int get activeCount => _engine.activeCount;

  /// Ids of toasts currently tracked.
  List<String> get activeIds => _engine.activeIds;

  /// Advisory device geometry / capability snapshot.
  Future<Map<String, dynamic>> queryGeometry() => _engine.queryGeometry();

  // ---------------------------------------------------------------------------
  // Test hooks
  // ---------------------------------------------------------------------------

  /// Resets all toast state. Test-only — lets each test start clean.
  @visibleForTesting
  Future<void> debugReset() => _engine.debugReset();

  /// Emits a native event into the router. Test-only.
  @visibleForTesting
  void debugEmit(ToastEvent event) => _engine.debugEmit(event);

  /// Simulates an action-button tap on the live toast [id]. Test/demo-only.
  @visibleForTesting
  Future<void> debugTriggerAction(String id) =>
      _engine.debugTriggerAction(id);

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  /// The single place a convenience [Toast] is constructed, including the
  /// omitted-vs-explicit-null duration resolution:
  /// explicit > [LiquidToastsConfig.defaultDuration] > per-semantic default.
  ToastHandle _semanticShow(
    ToastSemantic semantic,
    String message, {
    String? title,
    String? icon,
    ImageProvider? leadingImage,
    ToastStyleOverride? style,
    ToastPosition? position,
    Duration? duration = _useDefault,
    ToastAction? action,
    VoidCallback? onTap,
    bool tapToDismiss = true,
    String? groupKey,
    double? progress,
    ToastProgressStyle progressStyle = ToastProgressStyle.linear,
    ToastHaptic? haptic,
    String? semanticsLabel,
    int? maxLines,
    int? titleMaxLines,
    bool useDynamicIslandOrigin = true,
  }) {
    final resolvedDuration = identical(duration, _useDefault)
        ? (_engine.config.defaultDuration ??
            SemanticDefaults.durationFor(semantic))
        : duration;
    return _engine.show(Toast(
      message: message,
      title: title,
      icon: icon,
      leadingImage: leadingImage,
      semantic: semantic,
      style: style,
      position: position,
      duration: resolvedDuration,
      action: action,
      onTap: onTap,
      tapToDismiss: tapToDismiss,
      groupKey: groupKey,
      progress: progress,
      progressStyle: progressStyle,
      haptic: haptic,
      semanticsLabel: semanticsLabel,
      maxLines: maxLines,
      titleMaxLines: titleMaxLines,
      useDynamicIslandOrigin: useDynamicIslandOrigin,
    ));
  }

  Toast _promisePhase(
    ToastSemantic semantic,
    String message,
    ToastPosition? position,
    ToastStyleOverride? style,
    bool useDynamicIslandOrigin,
  ) =>
      Toast(
        message: message,
        semantic: semantic,
        position: position,
        style: style,
        duration: _engine.config.defaultDuration ??
            SemanticDefaults.durationFor(semantic),
        useDynamicIslandOrigin: useDynamicIslandOrigin,
      );
}
