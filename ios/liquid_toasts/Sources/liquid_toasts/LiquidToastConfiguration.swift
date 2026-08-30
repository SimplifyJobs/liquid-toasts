import Foundation

/// App-wide defaults for the `LiquidToast` facade, and the per-call duration
/// sentinel that reads them.
///
/// The Swift mirror of Dart's `LiquidToastsConfig`, minus the knobs that mean
/// nothing natively (`defaultGlass` is expressed per toast via
/// `ToastStyleModel.glass`).

// MARK: - Duration

/// How long a toast stays up.
///
/// [ToastDuration.default] is the *omitted* case — it resolves to
/// `LiquidToastConfiguration.defaultDuration`, or the per-semantic default
/// (`SemanticDefaults`) when that is unset. A non-positive interval is treated
/// as [persistent], matching Dart's `Duration.zero`.
public enum ToastDuration: Equatable, Sendable {
  /// The configured / per-semantic default.
  case `default`

  /// An explicit auto-dismiss interval, in seconds.
  case seconds(TimeInterval)

  /// Never auto-dismisses: only an explicit `dismiss()`, a swipe, or a tap
  /// removes it.
  case persistent

  public static func milliseconds(_ milliseconds: Int) -> ToastDuration {
    .seconds(TimeInterval(milliseconds) / 1000)
  }

  /// The wire duration in milliseconds, or nil when the toast is persistent.
  func resolvedMilliseconds(semantic: ToastSemantic, configured: TimeInterval?) -> Int? {
    let seconds: TimeInterval
    switch self {
    case .persistent: return nil
    case .default: seconds = configured ?? SemanticDefaults.duration(for: semantic)
    case .seconds(let value): seconds = value
    }
    return seconds > 0 ? Int(seconds * 1000) : nil
  }
}

// MARK: - Configuration

/// App-wide defaults applied by `LiquidToast.configure(_:)`. Values a call site
/// sets explicitly always win.
public struct LiquidToastConfiguration: Equatable {
  /// Where a toast anchors when the call site omits a position.
  public var defaultPosition: ToastPositionModel

  /// Auto-dismiss interval used when a call site omits `duration`. nil (the
  /// default) keeps the per-semantic defaults — success/warning/info 3s,
  /// error 4s.
  public var defaultDuration: TimeInterval?

  /// App-wide message line cap. nil keeps the semantic defaults (two lines for
  /// errors and warnings, one otherwise). A per-toast value always wins.
  public var maxLines: Int?

  /// App-wide title line cap. nil keeps the one-line default.
  public var titleMaxLines: Int?

  /// Minimum inset to keep clear at each screen edge, on top of the device
  /// safe area — space for a header, floating control or bottom bar.
  public var safeArea: ToastSafeAreaInsets

  /// Max toasts shown per position. Persistent and loading toasts are exempt
  /// from eviction, so a position full of them may exceed this.
  public var maxVisible: Int

  /// Reserved upper bound on total tracked toasts.
  public var maxQueue: Int

  /// Which toast loses when a position overflows: the oldest (default) or the
  /// newest — the native equivalent of Dart's `ToastDropPolicy`.
  public var dropOldest: Bool

  public init(
    defaultPosition: ToastPositionModel = .topCenter,
    defaultDuration: TimeInterval? = nil,
    maxLines: Int? = nil,
    titleMaxLines: Int? = nil,
    safeArea: ToastSafeAreaInsets = ToastSafeAreaInsets(),
    maxVisible: Int = 5,
    maxQueue: Int = 8,
    dropOldest: Bool = true
  ) {
    self.defaultPosition = defaultPosition
    self.defaultDuration = defaultDuration
    self.maxLines = maxLines
    self.titleMaxLines = titleMaxLines
    self.safeArea = safeArea
    self.maxVisible = maxVisible
    self.maxQueue = maxQueue
    self.dropOldest = dropOldest
  }
}
