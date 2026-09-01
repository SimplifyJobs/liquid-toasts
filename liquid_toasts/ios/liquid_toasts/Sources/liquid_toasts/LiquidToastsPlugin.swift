import Flutter
import LiquidToasts
import UIKit

/// Thin bridge between Flutter and the native overlay. Decodes method-channel
/// arguments into [ToastModel]s, drives [ToastManager], and streams lifecycle
/// events back over the event channel. Flutter invokes channel handlers on the
/// main thread, so UI is touched directly (no actor hop).
///
/// Everything it renders with comes from the `LiquidToasts` core package; this
/// target adds only the channel plumbing and the wire format.
public class LiquidToastsPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var eventSink: FlutterEventSink?

  /// This instance's subscription to the shared stack. Registered once (the
  /// manager fans out to every listener, so re-registering per call would stack
  /// duplicates) and released when the engine detaches — the manager is an
  /// app-lifetime singleton, so an orphaned entry would outlive this instance.
  /// The listener holds only a weak reference back, and a nil sink simply
  /// drops the event.
  private var eventToken: ToastEventToken?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let methods = FlutterMethodChannel(name: "liquid_toasts", binaryMessenger: registrar.messenger())
    let events = FlutterEventChannel(name: "liquid_toasts/events", binaryMessenger: registrar.messenger())
    let instance = LiquidToastsPlugin()
    registrar.addMethodCallDelegate(instance, channel: methods)
    events.setStreamHandler(instance)
    // Install the (empty) overlay eagerly so SwiftUI has rendered the container
    // before the first `show` — otherwise the first toast appears as initial
    // content and skips its entrance transition.
    MainActor.assumeIsolated {
      ToastOverlayHost.shared.ensureInstalled()
    }
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    MainActor.assumeIsolated {
      route(call, result: result)
    }
  }

  public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    MainActor.assumeIsolated {
      if let token = eventToken {
        ToastOverlayHost.shared.manager.removeEventListener(token)
        eventToken = nil
      }
      eventSink = nil
    }
  }

  @MainActor
  private func route(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let host = ToastOverlayHost.shared
    let manager = host.manager
    // Wire this plugin instance to the stack's events, once. Dart always calls
    // `handshake` before it listens, so the subscription is in place well
    // before the first event.
    if eventToken == nil {
      eventToken = manager.addEventListener { [weak self] payload in
        guard let self, let map = LiquidToastsPlugin.wireEvent(payload) else { return }
        self.eventSink?(map)
      }
    }

    let args = call.arguments as? [String: Any]

    switch call.method {
    case "handshake":
      // The Dart session prefix in the args is reserved wire data — native
      // flushes unconditionally on every handshake (fresh isolate = fresh UI).
      manager.flushAll()
      host.ensureInstalled()
      result(nil)

    case "configure":
      if let value = args?.int("maxVisible") { manager.maxVisible = max(1, value) }
      if let value = args?.int("maxQueue") { manager.maxQueue = max(1, value) }
      if let policy = args?["dropPolicy"] as? String { manager.dropOldest = policy != "dropNewest" }
      if let safeArea = args?["safeArea"] as? [String: Any] {
        let next = ToastSafeAreaInsets(
          top: safeArea.cgFloat("top") ?? 0,
          left: safeArea.cgFloat("left") ?? 0,
          bottom: safeArea.cgFloat("bottom") ?? 0,
          right: safeArea.cgFloat("right") ?? 0
        )
        if manager.customSafeArea != next { manager.customSafeArea = next }
      }
      result(nil)

    case "show":
      host.ensureInstalled()
      guard let model = ToastModel(arguments: args) else {
        result(FlutterError(code: "INVALID_ARGS", message: "show: missing id/message", details: nil))
        return
      }
      manager.present(model, imageData: (args?["image"] as? FlutterStandardTypedData)?.data)
      result([
        "id": model.id,
        "accepted": true,
        "capability": [
          "dynamicIslandOriginUsed": false,
          "glassMode": Capabilities.glassModeString,
        ],
      ])

    case "update":
      guard let id = args?["id"] as? String, let model = ToastModel(arguments: args) else {
        result(FlutterError(code: "INVALID_ARGS", message: "update: missing id/message", details: nil))
        return
      }
      let applied = manager.update(
        id: id, with: model,
        imageData: (args?["image"] as? FlutterStandardTypedData)?.data)
      var res: [String: Any] = ["id": id, "applied": applied]
      if !applied { res["reason"] = "unknown_id" }
      result(res)

    case "dismiss":
      guard let id = args?["id"] as? String else {
        result(FlutterError(code: "INVALID_ARGS", message: "dismiss: missing id", details: nil))
        return
      }
      let ok = manager.dismiss(id: id, reason: .manual)
      var res: [String: Any] = ["id": id, "dismissed": ok]
      if !ok { res["reason"] = "unknown_id" }
      result(res)

    case "dismissAll":
      // Dart always sends `dismissAll`; an unknown string falls back to it
      // rather than echoing an unmapped reason back over the wire.
      let reason = ToastDismissReason(rawValue: args?["reason"] as? String ?? "") ?? .dismissAll
      result(["dismissedIds": manager.dismissAll(reason: reason)])

    case "finishAction":
      if let id = args?["id"] as? String { manager.finishAction(id: id) }
      result(nil)

    case "debugTriggerAction":
      // Simulates an action-button tap (drives the spinner + lifecycle); used by
      // the example's async-action demo, which can't synthesize a real touch.
      if let id = args?["id"] as? String { manager.handleAction(id: id) }
      result(nil)

    case "queryGeometry":
      result(DynamicIslandGeometry.geometrySnapshot(ToastOverlayHost.activeWindow()))

    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Events

  /// Maps a typed core event onto the exact dictionary Dart's
  /// `ToastEvent.fromMap` expects, or nil for an event that deliberately does
  /// not cross the wire. Keys and strings are **wire protocol** — see the
  /// invariants in CLAUDE.md; keep them in lockstep with
  /// `liquid_toasts/lib/src/toast_event.dart`.
  private static func wireEvent(_ payload: ToastEventPayload) -> [String: Any]? {
    var map: [String: Any] = ["id": payload.id, "tsMs": payload.timestampMs]
    switch payload.kind {
    case .shown(let stackIndex):
      map["event"] = "shown"
      map["stackIndex"] = stackIndex
    case .actionTapped(let actionId):
      map["event"] = "actionTapped"
      map["actionId"] = actionId
    case .tapped:
      map["event"] = "tapped"
    case .dismissed(let reason):
      map["event"] = "dismissed"
      map["reason"] = reason.rawValue
    case .flushed:
      // A flush IS the hot-restart handshake: the sink that owned these toasts
      // is dead and the fresh isolate has never heard of their ids. Silence is
      // the contract — see `ToastManager.flushAll`.
      return nil
    }
    return map
  }

  // MARK: - FlutterStreamHandler

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }
}
