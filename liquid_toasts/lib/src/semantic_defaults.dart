import 'toast_style.dart';

/// Single source of truth for per-semantic presentation defaults.
///
/// Used by the [Toast] semantic factories, the engine's show-time duration
/// resolution, and the wire haptic derivation — so each default lives in
/// exactly one place instead of drifting across factory signatures.
///
/// LOCKSTEP: mirrored by `SemanticDefaults` in the native package
/// (`liquid-toasts-swift/Sources/LiquidToasts/SemanticDefaults.swift`), which
/// the `LiquidToast` Swift facade uses. The two facades must produce identical
/// toasts for the same call — change both tables or neither.
abstract final class SemanticDefaults {
  /// Const handles so factory signatures can reference them as parameter
  /// defaults (default values must be constant expressions).
  static const Duration successDuration = Duration(seconds: 3);
  static const Duration errorDuration = Duration(seconds: 4);
  static const Duration warningDuration = Duration(seconds: 3);
  static const Duration infoDuration = Duration(seconds: 3);
  static const Duration plainDuration = Duration(seconds: 3);

  /// Auto-dismiss duration when neither the caller nor the app config sets one.
  /// Errors linger a beat longer so they can be read.
  static Duration durationFor(ToastSemantic semantic) => switch (semantic) {
        ToastSemantic.success => successDuration,
        ToastSemantic.error => errorDuration,
        ToastSemantic.warning => warningDuration,
        ToastSemantic.info => infoDuration,
        ToastSemantic.none => plainDuration,
      };

  /// Message line cap: errors and warnings get room to explain themselves.
  static int maxLinesFor(ToastSemantic semantic) => switch (semantic) {
        ToastSemantic.error || ToastSemantic.warning => 2,
        ToastSemantic.success ||
        ToastSemantic.info ||
        ToastSemantic.none =>
          1,
      };

  /// Haptic fired on appear when the toast doesn't specify one.
  static ToastHaptic hapticFor(ToastSemantic semantic,
      {required bool loading}) {
    if (loading) return ToastHaptic.none;
    return switch (semantic) {
      ToastSemantic.success => ToastHaptic.success,
      ToastSemantic.error => ToastHaptic.error,
      ToastSemantic.warning => ToastHaptic.warning,
      ToastSemantic.info || ToastSemantic.none => ToastHaptic.none,
    };
  }
}
