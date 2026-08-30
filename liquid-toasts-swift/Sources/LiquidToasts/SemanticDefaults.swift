import Foundation

/// Single source of truth for per-semantic presentation defaults on the native
/// side: the duration, message line cap and appear-haptic a toast gets when the
/// caller doesn't set one.
///
/// **LOCKSTEP: mirrors `liquid_toasts/lib/src/semantic_defaults.dart`
/// exactly.** The Flutter facade and `LiquidToast` must produce identical
/// toasts for the same call, so every value here has a twin there — change
/// both or neither. (The Dart file carries the matching cross-reference
/// comment.)
enum SemanticDefaults {
  static let successDuration: TimeInterval = 3
  static let errorDuration: TimeInterval = 4
  static let warningDuration: TimeInterval = 3
  static let infoDuration: TimeInterval = 3
  static let plainDuration: TimeInterval = 3

  /// Auto-dismiss duration when neither the caller nor the app config sets one.
  /// Errors linger a beat longer so they can be read.
  static func duration(for semantic: ToastSemantic) -> TimeInterval {
    switch semantic {
    case .success: return successDuration
    case .error: return errorDuration
    case .warning: return warningDuration
    case .info: return infoDuration
    case .none: return plainDuration
    }
  }

  /// Message line cap: errors and warnings get room to explain themselves.
  static func maxLines(for semantic: ToastSemantic) -> Int {
    switch semantic {
    case .error, .warning: return 2
    case .success, .info, .none: return 1
    }
  }

  /// Haptic fired on appear when the toast doesn't specify one.
  static func haptic(for semantic: ToastSemantic, loading: Bool) -> ToastHapticKind {
    if loading { return ToastHapticKind.none }
    switch semantic {
    case .success: return ToastHapticKind.success
    case .error: return ToastHapticKind.error
    case .warning: return ToastHapticKind.warning
    case .info, .none: return ToastHapticKind.none
    }
  }
}
