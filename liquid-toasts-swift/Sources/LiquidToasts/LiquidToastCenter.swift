import UIKit

/// One live native toast's facade-side bookkeeping — the Swift mirror of the
/// Dart engine's `ToastRegistration`.
@MainActor
final class LiquidToastRegistration {
  init(
    handle: LiquidToastHandle,
    model: ToastModel,
    action: LiquidToastAction?,
    activeActionId: String?,
    onTap: (() -> Void)?,
    explicitHaptic: ToastHapticKind?
  ) {
    self.handle = handle
    self.lastModel = model
    self.action = action
    self.activeActionId = activeActionId
    self.onTap = onTap
    self.explicitHaptic = explicitHaptic
  }

  /// Held for the toast's lifetime so a caller who discarded the handle still
  /// gets its callbacks; released when the toast completes. The handle only
  /// stores an id, so nothing points back — no cycle.
  let handle: LiquidToastHandle

  /// The last *requested* state of the toast, so rapid-fire patches compose off
  /// each other instead of off stale state.
  var lastModel: ToastModel

  var action: LiquidToastAction?

  /// The action id currently live on screen. An `actionTapped` event carrying
  /// any other id is a press that raced an update, and is dropped.
  var activeActionId: String?

  var onTap: (() -> Void)?

  /// nil when the appear-haptic is derived from the semantic, so a later
  /// semantic change re-derives it — mirroring Dart's nullable `Toast.haptic`.
  var explicitHaptic: ToastHapticKind?

  /// Bumped on every update. An async action captures it before awaiting its
  /// handler; if it moved by completion, the newer content owns the lifecycle
  /// and the stale completion leaves it alone.
  var generation = 0
}

/// The engine behind `LiquidToast`: owns the native-caller registry (handles,
/// action/tap callbacks, generations), mints native ids, and routes the stack's
/// lifecycle events back to the right callbacks.
///
/// The Swift mirror of Dart's `ToastEngine`, minus the channel: `ToastManager`
/// is a direct call away, so there is no op chain and no handshake — a `show`
/// has already reached the stack by the time it returns.
@MainActor
final class LiquidToastCenter {
  static let shared = LiquidToastCenter()

  private init() {}

  var configuration = LiquidToastConfiguration()

  /// Maps a thrown error to a user-safe message for `LiquidToast.promise`.
  var errorMessageResolver: ((any Error) -> String)?

  private var registry: [String: LiquidToastRegistration] = [:]
  private var eventToken: ToastEventToken?
  private var lastActionCounter = 0

  var manager: ToastManager { ToastOverlayHost.shared.manager }

  var activeIds: [String] { Array(registry.keys) }
  var activeCount: Int { registry.count }

  // MARK: - Lifecycle

  /// Installs the overlay and subscribes to the stack — lazily, on first use.
  /// Idempotent: every entry point calls it. The Flutter plugin installs the
  /// overlay eagerly at registration instead, so its first toast still animates.
  func start() {
    ToastOverlayHost.shared.ensureInstalled()
    guard eventToken == nil else { return }
    eventToken = manager.addEventListener { [weak self] payload in
      self?.route(payload)
    }
  }

  func apply(_ configuration: LiquidToastConfiguration) {
    self.configuration = configuration
    start()
    manager.maxVisible = max(1, configuration.maxVisible)
    manager.maxQueue = max(1, configuration.maxQueue)
    manager.dropOldest = configuration.dropOldest
    if manager.customSafeArea != configuration.safeArea {
      manager.customSafeArea = configuration.safeArea
    }
  }

  // MARK: - Show

  /// The one place a facade toast is assembled — the mirror of Dart's
  /// `Toaster._semanticShow`, including the omitted-vs-explicit duration
  /// resolution (explicit > configured default > per-semantic default).
  func show(
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
    useDynamicIslandOrigin: Bool,
    loading: Bool
  ) -> LiquidToastHandle {
    start()
    let id = mintToastId()
    let (actionModel, actionId) = makeAction(action)
    var model = ToastModel(
      id: id,
      message: message,
      title: title,
      icon: icon,
      image: image.map { ToastImage(uiImage: $0) },
      expectsImage: image != nil,
      semantic: semantic,
      style: style,
      position: position ?? configuration.defaultPosition,
      state: loading ? .loading : .static,
      durationMs: duration.resolvedMilliseconds(
        semantic: semantic, configured: configuration.defaultDuration),
      useDynamicIslandOrigin: useDynamicIslandOrigin,
      progress: progress,
      progressStyle: progressStyle,
      groupKey: groupKey,
      haptic: haptic ?? SemanticDefaults.haptic(for: semantic, loading: loading),
      semanticsLabel: accessibilityLabel,
      maxLines: maxLines ?? configuration.maxLines ?? SemanticDefaults.maxLines(for: semantic),
      titleMaxLines: titleMaxLines ?? configuration.titleMaxLines ?? 1,
      tapToDismiss: tapToDismiss,
      // Always subscribed: the tap callback lives here and can be attached
      // after the fact (`LiquidToastHandle.onTap`), so the stack must always
      // report body taps. An unclaimed tap event is simply dropped.
      hasTap: true,
      action: actionModel)
    Self.applyPersistence(&model)

    let handle = LiquidToastHandle(id: id)
    // Registered BEFORE presenting: `present` emits `shown` synchronously, and
    // can even dismiss this very toast (a `dropOldest == false` overflow), so
    // the route must already find its registration.
    registry[id] = LiquidToastRegistration(
      handle: handle,
      model: model,
      action: action,
      activeActionId: actionId,
      onTap: onTap,
      explicitHaptic: haptic)
    manager.present(model)
    return handle
  }

  // MARK: - Update / dismiss

  /// Replaces toast [id]'s content wholesale (the stack morphs it in place) and
  /// rewires its callbacks. Returns false when the toast is already gone.
  @discardableResult
  func replace(
    id: String,
    model: ToastModel,
    action: LiquidToastAction?,
    onTap: (() -> Void)?,
    explicitHaptic: ToastHapticKind?
  ) -> Bool {
    guard let registration = registry[id] else { return false }
    var next = model
    let (actionModel, actionId) = makeAction(action)
    next.action = actionModel
    next.hasTap = true
    Self.applyPersistence(&next)
    // Rewired synchronously, before the stack sees the morph, so later patches
    // compose off this state and a stale action press can be told apart.
    registration.lastModel = next
    registration.action = action
    registration.activeActionId = actionId
    registration.onTap = onTap
    registration.explicitHaptic = explicitHaptic
    registration.generation += 1
    return manager.update(id: id, with: next)
  }

  /// The Dart `_promisePhase` mirror: a fresh success/error toast replacing the
  /// loading one. Wholesale rather than a patch, so the spinner, any progress
  /// and any action are cleared.
  func morph(
    id: String,
    semantic: ToastSemantic,
    message: String,
    position: ToastPositionModel?,
    style: ToastStyleModel?,
    useDynamicIslandOrigin: Bool
  ) {
    guard let registration = registry[id] else { return }
    var next = ToastModel(
      id: id,
      message: message,
      semantic: semantic,
      style: style,
      position: position ?? configuration.defaultPosition,
      durationMs: ToastDuration.default.resolvedMilliseconds(
        semantic: semantic, configured: configuration.defaultDuration),
      useDynamicIslandOrigin: useDynamicIslandOrigin,
      // Carried over: the stack keeps the live toast's group key across a
      // morph, so `lastModel` must too.
      groupKey: registration.lastModel.groupKey,
      haptic: SemanticDefaults.haptic(for: semantic, loading: false),
      maxLines: configuration.maxLines ?? SemanticDefaults.maxLines(for: semantic),
      titleMaxLines: configuration.titleMaxLines ?? 1)
    Self.applyPersistence(&next)
    replace(id: id, model: next, action: nil, onTap: nil, explicitHaptic: nil)
  }

  func dismiss(id: String, reason: ToastDismissReason = .manual) {
    guard registry[id] != nil else { return }
    // A `false` ack means the stack had already dropped it (an expected race):
    // complete locally so `onDismissed` never hangs.
    if !manager.dismiss(id: id, reason: reason) {
      complete(id: id, reason: reason)
    }
  }

  /// Dismisses every toast on the **shared** stack (Flutter's included, exactly
  /// as Dart's `dismissAll` clears native ones) and completes every native
  /// handle.
  func dismissAll(reason: ToastDismissReason = .dismissAll) {
    // Snapshot before the sweep: an `onDismissed` callback may show a NEW toast
    // mid-sweep, and that one is live (the manager snapshots its ids the same
    // way) — completing it here would strand a visible toast with a dead handle.
    let owned = Array(registry.keys)
    manager.dismissAll(reason: reason)
    // Safety net, scoped to the snapshot: anything the stack no longer knew
    // about completes locally.
    for id in owned {
      complete(id: id, reason: reason)
    }
  }

  func registration(for id: String) -> LiquidToastRegistration? { registry[id] }

  // MARK: - Event routing

  private func route(_ payload: ToastEventPayload) {
    // Unknown id: a Flutter-owned toast, or one this facade already completed.
    guard let registration = registry[payload.id] else { return }
    switch payload.kind {
    case .shown:
      break
    case .actionTapped(let actionId):
      // Drop a stale press that arrived after an update swapped the action.
      guard actionId == registration.activeActionId else { return }
      runAction(id: payload.id, registration: registration)
    case .tapped:
      registration.onTap?()
    case .dismissed(let reason):
      complete(id: payload.id, reason: reason)
    case .flushed:
      // The stack was cleared out from under us (a Flutter hot restart, or an
      // explicit `flushAll`). Resolve the handle so nothing waits forever.
      complete(id: payload.id, reason: .systemReset)
    }
  }

  /// Runs an action's handler, then finishes the lifecycle for an async
  /// (`loadingOnPress`) action — unless an update superseded it mid-await, in
  /// which case the newer content owns the toast.
  private func runAction(id: String, registration: LiquidToastRegistration) {
    guard let action = registration.action else { return }
    let generation = registration.generation
    Task { @MainActor in
      await action.handler()
      // Synchronous actions: the stack already tore the toast down on press
      // (per `dismissOnPress`), so there is nothing left to finish.
      guard action.loadingOnPress else { return }
      guard let live = self.registry[id],
            live === registration,
            registration.generation == generation else { return }
      if action.dismissOnPress {
        self.dismiss(id: id, reason: .action)
      } else {
        // Keep the toast up: clear the spinner and re-arm its auto-dismiss.
        self.manager.finishAction(id: id)
      }
    }
  }

  private func complete(id: String, reason: ToastDismissReason) {
    guard let registration = registry.removeValue(forKey: id) else { return }
    registration.handle.complete(reason)
  }

  // MARK: - Internals

  /// Native ids are `lt_native_<uuid>`; Dart mints `lt_<sessionPrefix>_<nnnn>`
  /// with a digits-only counter. The two namespaces can never collide, which is
  /// what lets both facades drive one stack.
  private func mintToastId() -> String {
    "lt_native_\(UUID().uuidString.lowercased())"
  }

  /// Unique within this process; only ever compared against the id stored on
  /// the same registration.
  private func mintActionId() -> String {
    lastActionCounter += 1
    return "na\(lastActionCounter)"
  }

  private func makeAction(_ action: LiquidToastAction?) -> (ToastActionModel?, String?) {
    guard let action else { return (nil, nil) }
    let actionId = mintActionId()
    return (
      ToastActionModel(
        actionId: actionId,
        label: action.label,
        role: action.role,
        color: action.color,
        dismissOnPress: action.dismissOnPress,
        loadingOnPress: action.loadingOnPress),
      actionId
    )
  }

  /// Persistence is derived, never set directly: a loading toast has no
  /// deadline, and no duration means persistent. Mirrors Dart's
  /// `Toast.isPersistent` and its wire encoding (`durationMs` omitted when
  /// persistent), so both facades clamp identically.
  static func applyPersistence(_ model: inout ToastModel) {
    if model.state == .loading { model.durationMs = nil }
    model.persistent = model.durationMs == nil
  }
}
