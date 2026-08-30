import Foundation

/// The single (at most one) action button on a toast shown through
/// `LiquidToast`.
///
/// [handler] never reaches the renderer: the facade keeps it keyed by toast id
/// and the stack only ever echoes back an opaque action id — the same
/// "callbacks never cross a wire" shape the Dart engine uses. An update that
/// swaps the action mints a fresh id, so a press that raced the update is
/// dropped instead of invoking the superseded handler.
public struct LiquidToastAction {
  /// Button label. Rendered as a fully-rounded capsule.
  public var label: String

  /// Drives the button color, adaptively, unless [color] overrides it.
  public var role: ToastActionRole

  /// Hard color override; bypasses [role]-to-color derivation.
  public var color: ToastColor?

  /// If true, the toast dismisses once the press is delivered — for a
  /// [loadingOnPress] action, once [handler] returns.
  public var dismissOnPress: Bool

  /// When true, pressing replaces the label with a spinner and keeps the toast
  /// up (auto-dismiss disarmed) until [handler] returns. Then, if
  /// [dismissOnPress] is true the toast dismisses; otherwise the spinner
  /// clears, the label returns and auto-dismiss re-arms.
  public var loadingOnPress: Bool

  /// Runs on the main actor when the button is pressed. May be async; a
  /// synchronous closure works unchanged. Errors are the caller's to handle —
  /// this cannot throw, so the lifecycle can never be left half-finished.
  public var handler: @MainActor () async -> Void

  public init(
    label: String,
    role: ToastActionRole = .primary,
    color: ToastColor? = nil,
    dismissOnPress: Bool = true,
    loadingOnPress: Bool = false,
    handler: @escaping @MainActor () async -> Void
  ) {
    self.label = label
    self.role = role
    self.color = color
    self.dismissOnPress = dismissOnPress
    self.loadingOnPress = loadingOnPress
    self.handler = handler
  }
}
