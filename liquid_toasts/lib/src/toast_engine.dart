import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../liquid_toasts_platform_interface.dart';
import 'ids.dart';
import 'liquid_toasts_config.dart';
import 'toast.dart';
import 'toast_action.dart';
import 'toast_event.dart';
import 'toast_handle.dart';
import 'toast_position.dart';
import 'toast_style.dart';

/// One live toast's Dart-side bookkeeping.
class ToastRegistration {
  ToastRegistration({
    required this.completer,
    required this.lastToast,
    this.action,
    this.activeActionId,
    this.onTap,
  });

  final Completer<ToastDismissReason> completer;

  /// The last *requested* state of the toast. Updated synchronously when a
  /// replace/patch is enqueued (before the platform op runs) so rapid-fire
  /// patches compose off each other instead of off stale state.
  Toast lastToast;

  ToastAction? action;
  String? activeActionId;
  VoidCallback? onTap;

  /// Bumped on every replace/patch. An async action captures the generation
  /// before awaiting `onPressed`; if it changed by completion, the newer
  /// content owns the lifecycle and the stale completion leaves it alone.
  int generation = 0;

  /// Serializes this toast's platform operations (show → update → dismiss) so
  /// a synchronous `show` can return a handle before its platform call lands:
  /// anything enqueued later waits its turn. Ops never leave an error on the
  /// chain — `_enqueue` converts failures to their fallback value.
  Future<void> opChain = Future<void>.value();
}

/// The internal engine behind both the global `toast` object and the
/// deprecated [LiquidToasts] facade. Owns the registry, the event
/// subscription, the handshake, and app-wide defaults.
///
/// Not exported from the package barrel — external code goes through
/// `toast` / `Toaster`.
class ToastEngine {
  ToastEngine._();

  static final ToastEngine instance = ToastEngine._();

  LiquidToastsPlatform get _platform => LiquidToastsPlatform.instance;

  final Map<String, ToastRegistration> _registry = {};
  StreamSubscription<ToastEvent>? _eventSub;

  /// In-flight (or completed) handshake, memoized so it runs once per session.
  /// Cleared on failure so the next show retries it.
  Future<void>? _handshake;

  LiquidToastsConfig _config = const LiquidToastsConfig();
  LiquidToastsConfig get config => _config;

  /// Optional global hook mapping a thrown error to a user-safe message, used
  /// by the promise/loading flows when no per-call error builder is supplied.
  String Function(Object error)? errorMessageResolver;

  /// Number of toasts currently tracked (visible + queued).
  int get activeCount => _registry.length;

  /// Ids of toasts currently tracked.
  List<String> get activeIds => _registry.keys.toList(growable: false);

  /// Sets app-wide defaults and pushes stack/queue configuration to native.
  Future<void> setDefaults(LiquidToastsConfig config) async {
    _config = config;
    await _ensureInit();
    await _platform.configure(config);
  }

  // ---------------------------------------------------------------------------
  // Show / update / dismiss
  // ---------------------------------------------------------------------------

  /// Shows [toast] and returns its handle **synchronously**. The platform call
  /// runs in the background on the toast's op chain; update/dismiss issued
  /// before it lands queue behind it. A failed or rejected show completes the
  /// handle with [ToastDismissReason.channelLost] — errors never surface to
  /// fire-and-forget callers.
  ToastHandle show(Toast toast) {
    final resolved = _resolveDefaults(toast);
    final id = nextToastId();
    final actionId = resolved.action != null ? nextActionId() : null;
    final reg = ToastRegistration(
      completer: Completer<ToastDismissReason>(),
      lastToast: resolved,
      action: resolved.action,
      activeActionId: actionId,
      onTap: resolved.onTap,
    );
    _registry[id] = reg;
    final handle = ToastHandle.internal(id, this, reg.completer);
    // Image resolution starts now, in parallel with the handshake; only this
    // toast's op chain waits on it. No-image toasts never touch the pipeline.
    final imageFuture = resolved.leadingImage == null
        ? null
        : _resolveImageBytes(resolved.leadingImage);
    _enqueue<void>(id, null, (_) async {
      try {
        await _ensureInit();
        final bytes = imageFuture == null ? null : await imageFuture;
        final accepted = await _platform.show(id, resolved,
            actionId: actionId, imageBytes: bytes);
        if (!accepted) _complete(id, ToastDismissReason.channelLost);
      } catch (e, st) {
        _logError(e, st);
        _complete(id, ToastDismissReason.channelLost);
      }
    });
    return handle;
  }

  /// Replaces toast [id]'s content wholesale (native morphs in place). Returns
  /// whether the update was applied (`false` if the toast was already gone —
  /// an expected race, not an error).
  Future<bool> replace(String id, Toast toast) {
    final reg = _registry[id];
    if (reg == null) return Future<bool>.value(false);
    final resolved = _resolveDefaults(toast);
    final actionId = resolved.action != null ? nextActionId() : null;
    // Rewire synchronously — before the platform op runs — so later patches
    // compose off this state and stale async-action completions can tell.
    reg.lastToast = resolved;
    reg.action = resolved.action;
    reg.activeActionId = actionId;
    reg.onTap = resolved.onTap;
    reg.generation++;
    final imageFuture = resolved.leadingImage == null
        ? null
        : _resolveImageBytes(resolved.leadingImage);
    return _enqueue<bool>(id, false, (_) async {
      final bytes = imageFuture == null ? null : await imageFuture;
      return _platform.update(id, resolved,
          actionId: actionId, imageBytes: bytes);
    });
  }

  /// Patch-style update: applies the given fields on top of the toast's last
  /// requested state ([ToastRegistration.lastToast]) via [Toast.copyWith].
  Future<bool> patch(
    String id, {
    String? message,
    String? title,
    String? icon,
    ImageProvider? leadingImage,
    ToastSemantic? semantic,
    ToastStyleOverride? style,
    ToastPosition? position,
    Duration? duration,
    ToastAction? action,
    bool? useDynamicIslandOrigin,
    VoidCallback? onTap,
    bool? tapToDismiss,
    String? groupKey,
    double? progress,
    ToastProgressStyle? progressStyle,
    ToastHaptic? haptic,
    String? semanticsLabel,
    int? maxLines,
    int? titleMaxLines,
    bool? loading,
  }) {
    final reg = _registry[id];
    if (reg == null) return Future<bool>.value(false);
    return replace(
      id,
      reg.lastToast.copyWith(
        message: message,
        title: title,
        icon: icon,
        leadingImage: leadingImage,
        semantic: semantic,
        style: style,
        position: position,
        duration: duration,
        action: action,
        useDynamicIslandOrigin: useDynamicIslandOrigin,
        onTap: onTap,
        tapToDismiss: tapToDismiss,
        groupKey: groupKey,
        progress: progress,
        progressStyle: progressStyle,
        haptic: haptic,
        semanticsLabel: semanticsLabel,
        maxLines: maxLines,
        titleMaxLines: titleMaxLines,
        loading: loading,
      ),
    );
  }

  /// Dismisses toast [id]. If native had already dropped it, the handle is
  /// completed locally so `onDismissed` never hangs.
  Future<void> dismiss(String id) {
    if (!_registry.containsKey(id)) return Future<void>.value();
    return _enqueue<void>(id, null, (_) async {
      final ok = await _platform.dismiss(id);
      if (!ok) _complete(id, ToastDismissReason.manual);
    });
  }

  /// Dismisses every toast. Completes every tracked handle, and chases any
  /// show still in flight (one that would land natively *after* the
  /// dismissAll) with an idempotent per-id dismiss so no native toast is
  /// orphaned.
  Future<void> dismissAll() async {
    final pending = Map<String, ToastRegistration>.of(_registry);
    List<String> dismissedIds = const [];
    try {
      dismissedIds = await _platform.dismissAll();
    } catch (e, st) {
      _logError(e, st);
    }
    for (final id in dismissedIds) {
      _complete(id, ToastDismissReason.dismissAll);
    }
    for (final entry in pending.entries) {
      if (!_registry.containsKey(entry.key)) continue; // already reconciled
      _complete(entry.key, ToastDismissReason.dismissAll);
      // A queued-but-not-started show sees its dead registration and no-ops;
      // an already-in-flight one lands natively, then this dismiss clears it.
      unawaited(entry.value.opChain
          .then((_) => _platform.dismiss(entry.key))
          .then<void>((_) {},
              onError: (Object e, StackTrace st) => _logError(e, st)));
    }
  }

  /// Waits until every operation enqueued so far for toast [id] has landed.
  /// Used by the deprecated facade (whose `show` awaited the platform ack)
  /// and by tests.
  Future<void> settle(String id) =>
      _registry[id]?.opChain ?? Future<void>.value();

  /// Advisory device geometry / capability snapshot.
  Future<Map<String, dynamic>> queryGeometry() => _platform.queryGeometry();

  // ---------------------------------------------------------------------------
  // Promise / loading
  // ---------------------------------------------------------------------------

  /// Ties [future] to a loading toast: shows [loading], then morphs to the
  /// [success]/[error] toast. **Returns the future's value** (or rethrows its
  /// error) so the caller owns the outcome — the visual is best-effort: if the
  /// toast was dismissed mid-flight the morph is skipped, and a throwing
  /// builder is logged and never corrupts the returned future.
  Future<T> promiseWith<T>(
    Future<T> future, {
    required Toast loading,
    required Toast Function(T value) success,
    required Toast Function(Object error, StackTrace stack) error,
  }) async {
    final handle = show(loading);
    try {
      final value = await future;
      await _morphGuarded(handle, () => success(value));
      return value;
    } catch (e, st) {
      await _morphGuarded(handle, () => error(e, st));
      rethrow;
    }
  }

  Future<void> _morphGuarded(ToastHandle handle, Toast Function() build) async {
    if (!handle.isShowing) return;
    Toast next;
    try {
      next = build();
    } catch (e, st) {
      _logError(e, st);
      await handle.dismiss();
      return;
    }
    await handle.replace(next);
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  /// Chains [op] onto toast [id]'s op chain. Ops run strictly in FIFO order
  /// per toast; different toasts never block each other. Failures resolve to
  /// [orElse] (after logging) so an error can never escape to a
  /// fire-and-forget caller or poison the chain.
  Future<T> _enqueue<T>(
    String id,
    T orElse,
    Future<T> Function(ToastRegistration reg) op,
  ) {
    final reg = _registry[id];
    if (reg == null) return Future<T>.value(orElse);
    final run = reg.opChain.then((_) async {
      // The registration may have been completed/removed while queued.
      if (!identical(_registry[id], reg)) return orElse;
      try {
        return await op(reg);
      } catch (e, st) {
        _logError(e, st);
        return orElse;
      }
    });
    reg.opChain = run.then<void>((_) {});
    return run;
  }

  /// Applies app-wide defaults that need omitted-vs-explicit tracking.
  Toast _resolveDefaults(Toast toast) {
    final positioned = toast.position == null
        ? toast.copyWith(position: _config.defaultPosition)
        : toast;
    return positioned.resolveLineLimits(
      maxLines: _config.maxLines,
      titleMaxLines: _config.titleMaxLines,
    );
  }

  /// Resolves an [ImageProvider] to PNG bytes via the Flutter image pipeline
  /// (no `BuildContext` needed) to hand to the native renderer. Returns null if
  /// it fails to load — the toast then shows without an image.
  Future<Uint8List?> _resolveImageBytes(ImageProvider? provider) async {
    if (provider == null) return null;
    final stream = provider.resolve(ImageConfiguration.empty);
    final completer = Completer<ui.Image>();
    final listener = ImageStreamListener(
      (ImageInfo info, bool _) {
        if (!completer.isCompleted) completer.complete(info.image);
      },
      onError: (Object e, StackTrace? st) {
        if (!completer.isCompleted) completer.completeError(e);
      },
    );
    stream.addListener(listener);
    try {
      // Bound the wait so a stalled provider (e.g. an unreachable NetworkImage)
      // can't hang the toast's op chain forever — it then renders without it.
      final image = await completer.future.timeout(const Duration(seconds: 5));
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } catch (e, st) {
      _logError(e, st);
      return null;
    } finally {
      stream.removeListener(listener);
    }
  }

  Future<void> _ensureInit() async {
    await (_handshake ??= _doHandshake());
    // (Re-)subscribe here rather than once: a lost channel nulls _eventSub so
    // the next show can recover.
    _eventSub ??= _platform.events.listen(
      _onEvent,
      onError: (Object e, StackTrace st) => _logError(e, st),
      onDone: () => _failAll(ToastDismissReason.channelLost),
      cancelOnError: false,
    );
  }

  Future<void> _doHandshake() async {
    try {
      await _platform.handshake(sessionPrefix);
    } catch (_) {
      _handshake = null; // retry on the next show
      rethrow;
    }
  }

  void _onEvent(ToastEvent e) {
    final reg = _registry[e.id];
    if (reg == null) return; // stale / unknown id
    switch (e.kind) {
      case ToastEventKind.action:
        // Drop a stale tap that arrived after an update swapped the action.
        if (e.actionId != null && e.actionId != reg.activeActionId) return;
        _runAction(e.id, reg);
      case ToastEventKind.tap:
        _guarded(reg.onTap);
      case ToastEventKind.dismissed:
        _complete(e.id, e.reason);
      case ToastEventKind.shown:
      case ToastEventKind.unknown:
        break;
    }
  }

  /// Runs an action's [ToastAction.onPressed] (sync or async), guarded. For a
  /// [ToastAction.loadingOnPress] action native keeps the toast up (spinner)
  /// while the future runs, so finish the lifecycle on completion — unless an
  /// update superseded this action mid-await (generation moved), in which case
  /// the newer content owns it.
  Future<void> _runAction(String id, ToastRegistration reg) async {
    final action = reg.action;
    if (action == null) return;
    final generation = reg.generation;
    try {
      await action.onPressed();
    } catch (e, st) {
      _logError(e, st);
    }
    // Sync actions: native already dismissed on tap (per dismissOnPress).
    if (!action.loadingOnPress) return;
    final live = _registry[id];
    if (!identical(live, reg) || reg.generation != generation) return;
    if (action.dismissOnPress) {
      await dismiss(id);
    } else {
      // Keep the toast up: clear the spinner and re-arm its auto-dismiss.
      await _enqueue<void>(id, null, (_) => _platform.finishAction(id));
    }
  }

  void _guarded(VoidCallback? cb) {
    if (cb == null) return;
    try {
      cb();
    } catch (e, st) {
      _logError(e, st);
    }
  }

  void _complete(String id, ToastDismissReason reason) {
    final reg = _registry.remove(id);
    if (reg == null) return;
    if (!reg.completer.isCompleted) reg.completer.complete(reason);
  }

  void _failAll(ToastDismissReason reason) {
    final regs = _registry.values.toList();
    _registry.clear();
    for (final r in regs) {
      if (!r.completer.isCompleted) r.completer.complete(reason);
    }
    _eventSub = null; // allow re-subscription on the next show
  }

  void _logError(Object e, StackTrace st) {
    if (kDebugMode) {
      debugPrint('[liquid_toasts] $e\n$st');
    }
  }

  // ---------------------------------------------------------------------------
  // Test hooks
  // ---------------------------------------------------------------------------

  /// Resets all engine state. Test-only — lets each test start clean.
  Future<void> debugReset() async {
    await _eventSub?.cancel();
    _eventSub = null;
    _registry.clear();
    _handshake = null;
    _config = const LiquidToastsConfig();
    errorMessageResolver = null;
  }

  /// Emits a native event into the engine's router. Test-only.
  void debugEmit(ToastEvent event) => _onEvent(event);

  /// Simulates an action-button tap on the live toast [id]. Test/demo-only.
  Future<void> debugTriggerAction(String id) =>
      _platform.debugTriggerAction(id);
}
