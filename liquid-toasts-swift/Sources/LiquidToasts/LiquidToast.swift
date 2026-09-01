import UIKit

/// The native toaster: premium, natively-drawn toasts on an overlay above your
/// app — with no view controller, no window and no environment plumbing.
///
/// ```swift
/// LiquidToast.success("Profile updated")
///
/// let upload = LiquidToast.loading("Uploading…", progress: 0)
/// upload.update(progress: 0.6)
/// upload.update(message: "Uploaded", semantic: .success, duration: .default, loading: false)
///
/// let user = try await LiquidToast.promise(
///   loading: "Signing in…",
///   success: { "Welcome back, \($0.name)!" },
///   error: { _ in "Sign-in failed" }
/// ) {
///   try await api.signIn(email, password)
/// }
/// ```
///
/// Everything here is main-actor isolated; the overlay installs itself on first
/// use. Toasts shown from Flutter and from Swift share one stack, so mixing the
/// two in a hybrid app is safe.
///
/// This is the layer to reach for. `ToastManager` underneath is public too, but
/// low-level: it deals in opaque ids and holds no callbacks.
@MainActor
public enum LiquidToast {
  // MARK: - Configuration

  /// Applies app-wide defaults (position, duration, line caps, stack limits,
  /// reserved safe area). Values a call site sets explicitly always win.
  public static func configure(_ configuration: LiquidToastConfiguration) {
    LiquidToastCenter.shared.apply(configuration)
  }

  /// The defaults currently in effect.
  public static var configuration: LiquidToastConfiguration {
    LiquidToastCenter.shared.configuration
  }

  /// Optional global hook mapping a thrown error to a user-safe message, used
  /// by [promise] when no per-call `error` builder is supplied. Keeps a raw
  /// error description from leaking internals into a user-facing toast.
  public static var errorMessageResolver: ((any Error) -> String)? {
    get { LiquidToastCenter.shared.errorMessageResolver }
    set { LiquidToastCenter.shared.errorMessageResolver = newValue }
  }

  /// Installs the overlay ahead of time. Optional — every show call does it —
  /// but calling it at launch keeps the very first toast's entrance smooth.
  public static func prepare() {
    LiquidToastCenter.shared.start()
  }

  // MARK: - Show

  /// Shows a toast and returns its handle.
  ///
  /// Omitting `duration` uses the configured default, falling back to the
  /// per-semantic one (3s, 4s for errors); pass `.persistent` for a toast that
  /// stays until it is dismissed.
  @discardableResult
  public static func show(
    _ message: String,
    title: String? = nil,
    icon: String? = nil,
    image: UIImage? = nil,
    semantic: ToastSemantic = .none,
    style: ToastStyleModel? = nil,
    position: ToastPositionModel? = nil,
    duration: ToastDuration = .default,
    action: LiquidToastAction? = nil,
    onTap: (() -> Void)? = nil,
    tapToDismiss: Bool = true,
    groupKey: String? = nil,
    progress: Double? = nil,
    progressStyle: ToastProgressStyle = .linear,
    haptic: ToastHapticKind? = nil,
    accessibilityLabel: String? = nil,
    maxLines: Int? = nil,
    titleMaxLines: Int? = nil
  ) -> LiquidToastHandle {
    present(
      semantic: semantic, message: message, title: title, icon: icon, image: image,
      style: style, position: position, duration: duration, action: action, onTap: onTap,
      tapToDismiss: tapToDismiss, groupKey: groupKey, progress: progress,
      progressStyle: progressStyle, haptic: haptic, accessibilityLabel: accessibilityLabel,
      maxLines: maxLines, titleMaxLines: titleMaxLines, loading: false)
  }

  /// A success toast: green check, success haptic, 3s.
  @discardableResult
  public static func success(
    _ message: String,
    title: String? = nil,
    icon: String? = nil,
    image: UIImage? = nil,
    style: ToastStyleModel? = nil,
    position: ToastPositionModel? = nil,
    duration: ToastDuration = .default,
    action: LiquidToastAction? = nil,
    onTap: (() -> Void)? = nil,
    tapToDismiss: Bool = true,
    groupKey: String? = nil,
    progress: Double? = nil,
    progressStyle: ToastProgressStyle = .linear,
    haptic: ToastHapticKind? = nil,
    accessibilityLabel: String? = nil,
    maxLines: Int? = nil,
    titleMaxLines: Int? = nil
  ) -> LiquidToastHandle {
    present(
      semantic: .success, message: message, title: title, icon: icon, image: image,
      style: style, position: position, duration: duration, action: action, onTap: onTap,
      tapToDismiss: tapToDismiss, groupKey: groupKey, progress: progress,
      progressStyle: progressStyle, haptic: haptic, accessibilityLabel: accessibilityLabel,
      maxLines: maxLines, titleMaxLines: titleMaxLines, loading: false)
  }

  /// An error toast: red glyph, error haptic, two lines and 4s (errors linger a
  /// beat longer so they can be read).
  @discardableResult
  public static func error(
    _ message: String,
    title: String? = nil,
    icon: String? = nil,
    image: UIImage? = nil,
    style: ToastStyleModel? = nil,
    position: ToastPositionModel? = nil,
    duration: ToastDuration = .default,
    action: LiquidToastAction? = nil,
    onTap: (() -> Void)? = nil,
    tapToDismiss: Bool = true,
    groupKey: String? = nil,
    progress: Double? = nil,
    progressStyle: ToastProgressStyle = .linear,
    haptic: ToastHapticKind? = nil,
    accessibilityLabel: String? = nil,
    maxLines: Int? = nil,
    titleMaxLines: Int? = nil
  ) -> LiquidToastHandle {
    present(
      semantic: .error, message: message, title: title, icon: icon, image: image,
      style: style, position: position, duration: duration, action: action, onTap: onTap,
      tapToDismiss: tapToDismiss, groupKey: groupKey, progress: progress,
      progressStyle: progressStyle, haptic: haptic, accessibilityLabel: accessibilityLabel,
      maxLines: maxLines, titleMaxLines: titleMaxLines, loading: false)
  }

  /// A warning toast: amber glyph, warning haptic, two lines.
  @discardableResult
  public static func warning(
    _ message: String,
    title: String? = nil,
    icon: String? = nil,
    image: UIImage? = nil,
    style: ToastStyleModel? = nil,
    position: ToastPositionModel? = nil,
    duration: ToastDuration = .default,
    action: LiquidToastAction? = nil,
    onTap: (() -> Void)? = nil,
    tapToDismiss: Bool = true,
    groupKey: String? = nil,
    progress: Double? = nil,
    progressStyle: ToastProgressStyle = .linear,
    haptic: ToastHapticKind? = nil,
    accessibilityLabel: String? = nil,
    maxLines: Int? = nil,
    titleMaxLines: Int? = nil
  ) -> LiquidToastHandle {
    present(
      semantic: .warning, message: message, title: title, icon: icon, image: image,
      style: style, position: position, duration: duration, action: action, onTap: onTap,
      tapToDismiss: tapToDismiss, groupKey: groupKey, progress: progress,
      progressStyle: progressStyle, haptic: haptic, accessibilityLabel: accessibilityLabel,
      maxLines: maxLines, titleMaxLines: titleMaxLines, loading: false)
  }

  /// An info toast: blue glyph, no haptic.
  @discardableResult
  public static func info(
    _ message: String,
    title: String? = nil,
    icon: String? = nil,
    image: UIImage? = nil,
    style: ToastStyleModel? = nil,
    position: ToastPositionModel? = nil,
    duration: ToastDuration = .default,
    action: LiquidToastAction? = nil,
    onTap: (() -> Void)? = nil,
    tapToDismiss: Bool = true,
    groupKey: String? = nil,
    progress: Double? = nil,
    progressStyle: ToastProgressStyle = .linear,
    haptic: ToastHapticKind? = nil,
    accessibilityLabel: String? = nil,
    maxLines: Int? = nil,
    titleMaxLines: Int? = nil
  ) -> LiquidToastHandle {
    present(
      semantic: .info, message: message, title: title, icon: icon, image: image,
      style: style, position: position, duration: duration, action: action, onTap: onTap,
      tapToDismiss: tapToDismiss, groupKey: groupKey, progress: progress,
      progressStyle: progressStyle, haptic: haptic, accessibilityLabel: accessibilityLabel,
      maxLines: maxLines, titleMaxLines: titleMaxLines, loading: false)
  }

  /// A persistent spinner toast. Morph it later with `LiquidToastHandle.update`
  /// or remove it with `LiquidToastHandle.dismiss`; [promise] does both for you.
  ///
  /// It never auto-dismisses and ignores body taps, so it can't vanish while
  /// the work it represents is still running.
  @discardableResult
  public static func loading(
    _ message: String,
    title: String? = nil,
    icon: String? = nil,
    style: ToastStyleModel? = nil,
    position: ToastPositionModel? = nil,
    groupKey: String? = nil,
    progress: Double? = nil,
    progressStyle: ToastProgressStyle = .linear,
    accessibilityLabel: String? = nil,
    maxLines: Int? = nil,
    titleMaxLines: Int? = nil
  ) -> LiquidToastHandle {
    present(
      semantic: ToastSemantic.none, message: message, title: title, icon: icon, image: nil,
      style: style, position: position, duration: .persistent, action: nil, onTap: nil,
      tapToDismiss: false, groupKey: groupKey, progress: progress,
      progressStyle: progressStyle, haptic: nil, accessibilityLabel: accessibilityLabel,
      maxLines: maxLines, titleMaxLines: titleMaxLines, loading: true)
  }

  // MARK: - Promise

  /// Ties an async operation to a toast: a spinner while it runs, then a
  /// success or error toast.
  ///
  /// **Returns the operation's value (or rethrows its error)** so the caller
  /// always owns the outcome — the visual is best-effort and never swallows a
  /// result: if the toast was dismissed mid-flight, the morph is simply skipped.
  ///
  /// [perform] inherits the isolation of the context you write it in (main-actor
  /// when called from main-actor code, otherwise the cooperative pool). It is
  /// awaited, never blocking, but genuinely CPU-bound work should still hop to
  /// its own executor.
  ///
  /// ```swift
  /// let order = try await LiquidToast.promise(
  ///   loading: "Placing order…",
  ///   success: { "Order \($0.number) placed" }
  /// ) {
  ///   try await api.placeOrder(cart)
  /// }
  /// ```
  @discardableResult
  public static func promise<T>(
    loading message: String = "Loading…",
    success successMessage: ((T) -> String)? = nil,
    error errorMessage: ((any Error) -> String)? = nil,
    position: ToastPositionModel? = nil,
    style: ToastStyleModel? = nil,
    perform work: () async throws -> T
  ) async throws -> T {
    let handle = LiquidToast.loading(
      message,
      style: style,
      position: position)
    do {
      let value = try await work()
      morph(handle, semantic: .success, message: successMessage?(value) ?? "Done",
            position: position, style: style)
      return value
    } catch let failure {
      let text = errorMessage?(failure)
        ?? errorMessageResolver?(failure)
        ?? failure.localizedDescription
      morph(handle, semantic: .error, message: text,
            position: position, style: style)
      throw failure
    }
  }

  // MARK: - Management

  /// Dismisses toast [id]. Prefer `LiquidToastHandle.dismiss()` when you hold a
  /// handle.
  public static func dismiss(_ id: String) {
    LiquidToastCenter.shared.dismiss(id: id, reason: .manual)
  }

  /// Dismisses every toast on the stack — including any shown from Flutter in a
  /// hybrid app, since the stack is shared.
  public static func dismissAll() {
    LiquidToastCenter.shared.dismissAll()
  }

  /// Ids of the toasts this facade is currently tracking.
  public static var activeIds: [String] { LiquidToastCenter.shared.activeIds }

  /// How many toasts this facade is currently tracking.
  public static var activeCount: Int { LiquidToastCenter.shared.activeCount }

  /// Advisory device geometry / capability snapshot (safe area, screen, cutout,
  /// glass mode).
  public static func geometrySnapshot() -> [String: Any] {
    DynamicIslandGeometry.geometrySnapshot(ToastOverlayHost.activeWindow())
  }

  // MARK: - Internals

  /// The one funnel every show variant goes through, so the parameter list and
  /// its defaults exist in exactly one place (mirroring Dart's
  /// `Toaster._semanticShow`).
  private static func present(
    semantic: ToastSemantic,
    message: String,
    title: String?,
    icon: String?,
    image: UIImage?,
    style: ToastStyleModel?,
    position: ToastPositionModel?,
    duration: ToastDuration,
    action: LiquidToastAction?,
    onTap: (() -> Void)?,
    tapToDismiss: Bool,
    groupKey: String?,
    progress: Double?,
    progressStyle: ToastProgressStyle,
    haptic: ToastHapticKind?,
    accessibilityLabel: String?,
    maxLines: Int?,
    titleMaxLines: Int?,
    loading: Bool
  ) -> LiquidToastHandle {
    LiquidToastCenter.shared.show(
      semantic: semantic,
      message: message,
      title: title,
      icon: icon,
      image: image,
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
      accessibilityLabel: accessibilityLabel,
      maxLines: maxLines,
      titleMaxLines: titleMaxLines,
      loading: loading)
  }

  /// Best-effort promise morph: skipped when the toast is already gone.
  private static func morph(
    _ handle: LiquidToastHandle,
    semantic: ToastSemantic,
    message: String,
    position: ToastPositionModel?,
    style: ToastStyleModel?
  ) {
    guard handle.isShowing else { return }
    LiquidToastCenter.shared.morph(
      id: handle.id,
      semantic: semantic,
      message: message,
      position: position,
      style: style)
  }
}
