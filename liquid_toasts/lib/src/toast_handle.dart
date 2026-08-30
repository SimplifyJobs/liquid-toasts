import 'dart:async';
import 'dart:ui' show VoidCallback;

import 'package:flutter/painting.dart' show ImageProvider;

import 'toast.dart';
import 'toast_action.dart';
import 'toast_engine.dart';
import 'toast_event.dart';
import 'toast_position.dart';
import 'toast_style.dart';

/// A live controller for a shown toast, returned **synchronously** by every
/// `show` call.
///
/// Lets callers [update] (patch), [replace], or [dismiss] a (typically
/// persistent) toast and `await` its dismissal. The backing completer is
/// **always** completed — by the terminal native event, by `dismissAll`
/// reconciliation, or fail-safe if the event channel is lost — so
/// `await handle.onDismissed` never hangs.
class ToastHandle {
  /// Internal: constructed by the engine, which owns the completer. Not
  /// intended for direct use.
  ToastHandle.internal(this.id, this._engine, this._completer);

  final String id;
  final ToastEngine _engine;
  final Completer<ToastDismissReason> _completer;

  bool get isShowing => !_completer.isCompleted;
  bool get isDismissed => _completer.isCompleted;

  /// Resolves when the toast leaves the screen, with the reason.
  Future<ToastDismissReason> get onDismissed => _completer.future;

  /// Patch-style update: only the fields you pass change; everything else is
  /// kept from the toast's last requested state. Native cross-fades / morphs
  /// the content in place.
  ///
  /// Rapid-fire patches compose — `update(progress: .1)` then
  /// `update(progress: .2)` both land, in order, even before the first reaches
  /// native. To make a toast persistent pass `duration: Duration.zero`; to
  /// *clear* a nullable field (title, action, progress, …) use [replace].
  ///
  /// Returns whether the update was applied (`false` if already dismissed or
  /// the native toast was gone — an expected race, not an error).
  Future<bool> update({
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
  }) =>
      isShowing
          ? _engine.patch(
              id,
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
            )
          : Future<bool>.value(false);

  /// Replaces this toast's content wholesale with [toast] (the way to clear
  /// nullable fields). Returns whether it was applied.
  Future<bool> replace(Toast toast) =>
      isShowing ? _engine.replace(id, toast) : Future<bool>.value(false);

  /// Explicit dismissal. The only way to remove a persistent toast (besides a
  /// user swipe / tap). No-op if already dismissed.
  Future<void> dismiss() =>
      isShowing ? _engine.dismiss(id) : Future<void>.value();
}
