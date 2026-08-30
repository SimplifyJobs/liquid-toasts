import UIKit

/// A live controller for a shown toast, returned by every `LiquidToast` show
/// call.
///
/// Lets you patch the toast ([update]), remove it ([dismiss]), attach a body-tap
/// callback ([onTap]) and learn how it went away ([onDismissed] / [dismissal]).
/// Keeping the handle is optional: the facade holds it until the toast is gone,
/// so a callback attached to a discarded handle still fires.
///
/// Main-actor isolated, like everything in the facade.
@MainActor
public final class LiquidToastHandle {
  /// The toast's opaque id (`lt_native_…`), the same id the stack and its
  /// events use.
  public let id: String

  /// How the toast went away, or nil while it is still on screen.
  public private(set) var dismissReason: ToastDismissReason?

  public var isShowing: Bool { dismissReason == nil }
  public var isDismissed: Bool { dismissReason != nil }

  private var dismissalHandlers: [(ToastDismissReason) -> Void] = []
  private var continuations: [CheckedContinuation<ToastDismissReason, Never>] = []

  init(id: String) { self.id = id }

  // MARK: - Callbacks

  /// Called once when the toast leaves the screen — immediately if it already
  /// has. Handlers are released after firing, so a closure that captures this
  /// handle can't strand it.
  @discardableResult
  public func onDismissed(
    _ handler: @escaping (ToastDismissReason) -> Void
  ) -> LiquidToastHandle {
    if let dismissReason {
      handler(dismissReason)
    } else {
      dismissalHandlers.append(handler)
    }
    return self
  }

  /// Called when the toast body is tapped. Runs in addition to `tapToDismiss`;
  /// replaces any handler set at show time. Attaching one later is free — the
  /// facade always subscribes to body taps.
  @discardableResult
  public func onTap(_ handler: @escaping () -> Void) -> LiquidToastHandle {
    LiquidToastCenter.shared.registration(for: id)?.onTap = handler
    return self
  }

  /// Awaits the toast's dismissal. Resolves immediately if it is already gone;
  /// otherwise suspends until it is. A persistent toast nobody dismisses
  /// suspends forever — same contract as Dart's `handle.onDismissed`.
  public var dismissal: ToastDismissReason {
    get async {
      if let dismissReason { return dismissReason }
      // The body runs synchronously on this actor before suspending, so a
      // dismissal can't slip in between the check above and this append.
      return await withCheckedContinuation { continuation in
        self.continuations.append(continuation)
      }
    }
  }

  // MARK: - Mutation

  /// Patch-style update: only the fields you pass change; everything else is
  /// kept from the toast's last requested state, and the stack morphs the
  /// content in place.
  ///
  /// Passing nil means *keep* — to clear a value (drop the title, the action,
  /// the progress bar) show a fresh toast instead. `groupKey` and
  /// `useDynamicIslandOrigin` are fixed at show time and are deliberately
  /// absent: the renderer ignores them on a morph.
  ///
  /// Returns whether it was applied (false when the toast is already gone — an
  /// expected race, not an error).
  @discardableResult
  public func update(
    message: String? = nil,
    title: String? = nil,
    icon: String? = nil,
    image: UIImage? = nil,
    semantic: ToastSemantic? = nil,
    style: ToastStyleModel? = nil,
    position: ToastPositionModel? = nil,
    duration: ToastDuration? = nil,
    action: LiquidToastAction? = nil,
    onTap: (() -> Void)? = nil,
    tapToDismiss: Bool? = nil,
    progress: Double? = nil,
    progressStyle: ToastProgressStyle? = nil,
    haptic: ToastHapticKind? = nil,
    accessibilityLabel: String? = nil,
    maxLines: Int? = nil,
    titleMaxLines: Int? = nil,
    loading: Bool? = nil
  ) -> Bool {
    guard isShowing,
          let registration = LiquidToastCenter.shared.registration(for: id) else { return false }

    var next = registration.lastModel
    if let message { next.message = message }
    if let title { next.title = title }
    if let icon { next.icon = icon }
    if let image {
      next.image = ToastImage(uiImage: image)
      next.expectsImage = true
    }
    if let semantic { next.semantic = semantic }
    if let style { next.style = style }
    if let position { next.position = position }
    if let progress { next.progress = progress }
    if let progressStyle { next.progressStyle = progressStyle }
    if let accessibilityLabel { next.semanticsLabel = accessibilityLabel }
    if let maxLines { next.maxLines = maxLines }
    if let titleMaxLines { next.titleMaxLines = titleMaxLines }
    if let tapToDismiss { next.tapToDismiss = tapToDismiss }
    if let loading { next.state = loading ? .loading : .static }
    if let duration {
      next.durationMs = duration.resolvedMilliseconds(
        semantic: next.semantic,
        configured: LiquidToastCenter.shared.configuration.defaultDuration)
    }

    // A derived appear-haptic re-derives from the *new* semantic, while one the
    // caller set explicitly survives the patch — mirroring Dart, where the
    // haptic is resolved from a nullable field at wire time.
    let explicitHaptic = haptic ?? registration.explicitHaptic
    next.haptic = explicitHaptic
      ?? SemanticDefaults.haptic(for: next.semantic, loading: next.state == .loading)

    return LiquidToastCenter.shared.replace(
      id: id,
      model: next,
      action: action ?? registration.action,
      onTap: onTap ?? registration.onTap,
      explicitHaptic: explicitHaptic)
  }

  /// Explicit dismissal — the only way to remove a persistent toast short of a
  /// user swipe or tap. No-op once dismissed.
  public func dismiss() {
    guard isShowing else { return }
    LiquidToastCenter.shared.dismiss(id: id, reason: .manual)
  }

  // MARK: - Completion (facade-internal)

  /// Resolves the handle exactly once, then drops every callback it held.
  func complete(_ reason: ToastDismissReason) {
    guard dismissReason == nil else { return }
    dismissReason = reason
    let handlers = dismissalHandlers
    let pending = continuations
    dismissalHandlers = []
    continuations = []
    for handler in handlers { handler(reason) }
    for continuation in pending { continuation.resume(returning: reason) }
  }
}
