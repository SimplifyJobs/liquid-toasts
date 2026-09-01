import SwiftUI
import UIKit

/// A transparent container view added above the Flutter content in the **same**
/// window (so Liquid Glass can sample the live app behind it). It only swallows
/// touches that land on an actual toast frame; everything else falls through to
/// Flutter.
final class PassthroughHostView: UIView {
  weak var manager: ToastManager?
  var onSafeAreaInsetsChanged: ((UIEdgeInsets) -> Void)?

  override func safeAreaInsetsDidChange() {
    super.safeAreaInsetsDidChange()
    onSafeAreaInsetsChanged?(safeAreaInsets)
  }

  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    guard let frames = manager?.frames, !frames.isEmpty else { return nil }
    let global = convert(point, to: nil)
    let onToast = frames.values.contains { $0.contains(global) }
    guard onToast else { return nil }
    return super.hitTest(point, with: event)
  }
}

/// Installs and owns the overlay. Lives for the app's lifetime as a singleton so
/// its `ToastManager` survives across individual toasts (and a hot restart is
/// handled explicitly via `flushAll`).
///
/// The overlay is a transparent view added above the app's own content **in the
/// same window**, so Liquid Glass can sample what is behind it. `LiquidToast`
/// installs it lazily on first use; call [ensureInstalled] yourself only to
/// front-load that work (the Flutter plugin does, at registration, so the very
/// first toast still gets its entrance transition).
@MainActor
public final class ToastOverlayHost {
  public static let shared = ToastOverlayHost()

  /// The one stack this app draws. Low-level: see `ToastManager`.
  public let manager = ToastManager()

  private var hostController: UIHostingController<ToastContainerView>?
  private weak var hostView: PassthroughHostView?
  private var observersAdded = false

  private init() {}

  /// Ensures the overlay is attached to the active window. Idempotent, and safe
  /// to call before a window exists — it retries on the next runloop and on
  /// scene activation.
  public func ensureInstalled() {
    addObserversIfNeeded()
    guard hostController == nil else { return }
    guard let window = Self.activeWindow(), let root = window.rootViewController else {
      DispatchQueue.main.async { [weak self] in
        guard let self, self.hostController == nil else { return }
        if Self.activeWindow()?.rootViewController != nil { self.ensureInstalled() }
      }
      return
    }
    install(in: root)
  }

  private func install(in root: UIViewController) {
    let controller = UIHostingController(rootView: ToastContainerView(manager: manager))
    controller.view.backgroundColor = .clear
    controller.view.isOpaque = false
    controller.view.translatesAutoresizingMaskIntoConstraints = false

    let host = PassthroughHostView()
    host.manager = manager
    host.onSafeAreaInsetsChanged = { [weak self] insets in
      self?.manager.updateDeviceSafeArea(insets)
    }
    host.backgroundColor = .clear
    host.translatesAutoresizingMaskIntoConstraints = false

    root.addChild(controller)
    host.addSubview(controller.view)
    root.view.addSubview(host)
    controller.didMove(toParent: root)

    NSLayoutConstraint.activate([
      host.topAnchor.constraint(equalTo: root.view.topAnchor),
      host.bottomAnchor.constraint(equalTo: root.view.bottomAnchor),
      host.leadingAnchor.constraint(equalTo: root.view.leadingAnchor),
      host.trailingAnchor.constraint(equalTo: root.view.trailingAnchor),
      controller.view.topAnchor.constraint(equalTo: host.topAnchor),
      controller.view.bottomAnchor.constraint(equalTo: host.bottomAnchor),
      controller.view.leadingAnchor.constraint(equalTo: host.leadingAnchor),
      controller.view.trailingAnchor.constraint(equalTo: host.trailingAnchor),
    ])

    hostController = controller
    hostView = host
    refreshGeometry()
  }

  /// Recomputes device safe-area geometry onto the manager. The manager writes
  /// only on change; this also fires on every scene activation.
  func refreshGeometry() {
    manager.updateDeviceSafeArea(Self.activeWindow()?.safeAreaInsets ?? .zero)
  }

  /// Keeps the overlay frontmost if the app later adds sibling views.
  func bringToFront() {
    guard let host = hostView, let superview = host.superview else { return }
    superview.bringSubviewToFront(host)
  }

  /// The window the overlay installs into: the foreground-active scene's key
  /// window, with progressively looser fallbacks.
  public static func activeWindow() -> UIWindow? {
    let windowScenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let scene = windowScenes.first { $0.activationState == .foregroundActive }
      ?? windowScenes.first { $0.activationState == .foregroundInactive }
      ?? windowScenes.first
    guard let scene else { return nil }
    return scene.windows.first { $0.isKeyWindow } ?? scene.windows.first
  }

  private func addObserversIfNeeded() {
    guard !observersAdded else { return }
    observersAdded = true
    let center = NotificationCenter.default

    center.addObserver(forName: UIScene.didActivateNotification, object: nil, queue: .main) { [weak self] _ in
      MainActor.assumeIsolated {
        guard let self else { return }
        if self.hostController == nil { self.ensureInstalled() } else { self.bringToFront() }
        self.refreshGeometry()
      }
    }
    center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
      MainActor.assumeIsolated { self?.manager.appDidEnterBackground() }
    }
    center.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] _ in
      MainActor.assumeIsolated { self?.manager.appWillEnterForeground() }
    }
  }
}
