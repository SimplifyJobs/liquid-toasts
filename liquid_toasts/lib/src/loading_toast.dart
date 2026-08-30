import 'package:meta/meta.dart';

import 'toast.dart';
import 'toast_position.dart';
import 'toast_style.dart';

/// Static configuration for the three phases of a loading toast (loading →
/// success | error). Anything left null inherits a native semantic default.
///
/// For dynamic, value-derived content use the `onSuccess` / `onError` builders
/// on [LiquidToasts.showLoading], which take precedence over these fields.
@Deprecated("Use toast.promise(...)'s loading/success/error parameters "
    '(each takes a String, Toast, or builder). Removed in 1.0.')
@immutable
class LoadingToast {
  const LoadingToast({
    required this.loadingMessage,
    this.loadingTitle,
    this.loadingIcon,
    this.position = ToastPosition.topCenter,
    this.style,
    this.useDynamicIslandOrigin = true,
    // success phase
    this.successMessage = 'Done',
    this.successTitle,
    this.successIcon,
    this.successStyle,
    this.successDuration = const Duration(seconds: 2),
    // error phase
    this.errorMessage,
    this.errorTitle,
    this.errorIcon,
    this.errorStyle,
    this.errorDuration = const Duration(seconds: 4),
  });

  final String loadingMessage;
  final String? loadingTitle;
  final String? loadingIcon;
  final ToastPosition position;
  final ToastStyleOverride? style;
  final bool useDynamicIslandOrigin;

  final String successMessage;
  final String? successTitle;
  final String? successIcon;
  final ToastStyleOverride? successStyle;
  final Duration successDuration;

  /// Shown verbatim to the end user when no `onError` builder and no global
  /// resolver provides a message. As a last resort `error.toString()` is used —
  /// avoid leaking internals: prefer `onError` or a global resolver.
  final String? errorMessage;
  final String? errorTitle;
  final String? errorIcon;
  final ToastStyleOverride? errorStyle;
  final Duration errorDuration;

  /// The persistent spinner toast shown while the task runs.
  Toast buildLoading() => Toast.loading(
        message: loadingMessage,
        title: loadingTitle,
        icon: loadingIcon,
        style: style,
        position: position,
        useDynamicIslandOrigin: useDynamicIslandOrigin,
      );

  /// The default success toast (used when no `onSuccess` builder is given).
  Toast buildSuccess() => Toast.success(
        message: successMessage,
        title: successTitle,
        icon: successIcon,
        style: successStyle ?? style,
        position: position,
        duration: successDuration,
        useDynamicIslandOrigin: useDynamicIslandOrigin,
      );

  /// The default error toast. [resolvedMessage] (from a global resolver) wins
  /// over [errorMessage], which wins over `error.toString()`.
  Toast buildError(Object error, {String? resolvedMessage}) => Toast.error(
        message: resolvedMessage ?? errorMessage ?? error.toString(),
        title: errorTitle,
        icon: errorIcon,
        style: errorStyle ?? style,
        position: position,
        duration: errorDuration,
        useDynamicIslandOrigin: useDynamicIslandOrigin,
      );
}
