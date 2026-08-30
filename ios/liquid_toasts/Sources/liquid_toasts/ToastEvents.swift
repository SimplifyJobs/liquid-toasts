import Foundation

/// The lifecycle surface of the toast stack: why a toast left, what happened to
/// it, and the token that identifies a subscriber.
///
/// [ToastDismissReason]'s raw values are **wire strings** shared verbatim with
/// the Flutter bridge and Dart's `ToastDismissReason` — see the wire-protocol
/// invariants in CLAUDE.md. Change them only in lockstep with
/// `lib/src/toast_event.dart`.

// MARK: - Dismiss reason

/// Why a toast left the screen.
///
/// Dart declares two further reasons (`channelLost`, `unknown`) that it
/// synthesizes when the channel misbehaves; they never originate here, so they
/// are deliberately absent.
public enum ToastDismissReason: String, Sendable {
  /// The auto-dismiss duration elapsed.
  case timeout

  /// Programmatic dismissal (`ToastManager.dismiss`, `LiquidToastHandle.dismiss`).
  case manual

  /// The user swiped the toast away.
  case swipe

  /// Dismissed as a side effect of the action button (`dismissOnPress`).
  case action

  /// Dismissed by tapping the toast body (`tapToDismiss`).
  case tap

  /// Replaced in place — by a same-`groupKey` toast, or evicted to keep a
  /// position within `maxVisible`.
  case replaced

  /// Cleared by `dismissAll`.
  case dismissAll

  /// Torn down because the app was backgrounded past the deadline.
  case appBackgrounded

  /// The whole stack was flushed (`ToastManager.flushAll`, e.g. a Flutter hot
  /// restart). Never crosses the Flutter wire — a flush is silent by contract —
  /// but native handles resolve with it so nothing waits forever.
  case systemReset
}

// MARK: - Event payload

/// A lifecycle event for a single toast, fanned out to every listener
/// registered with [ToastManager].
///
/// Low-level: the Flutter bridge maps these onto its event channel, and
/// `LiquidToast` routes them to native handles and callbacks.
public struct ToastEventPayload: Equatable, Sendable {
  /// What happened, with the payload that only makes sense for that case.
  public enum Kind: Equatable, Sendable {
    /// The toast entered the stack at [stackIndex].
    case shown(stackIndex: Int)

    /// The action button was pressed. [actionId] echoes the id the caller minted
    /// at show time so a tap that raced an update can be dropped.
    case actionTapped(actionId: String)

    /// The toast body was tapped (only emitted when `ToastModel.hasTap`).
    case tapped

    /// The toast left the screen. Terminal — nothing further is emitted for it.
    case dismissed(reason: ToastDismissReason)

    /// The toast was dropped by a silent `ToastManager.flushAll()` rather than
    /// dismissed. Also terminal; owners should release it, resolving anything
    /// they hold with `ToastDismissReason.systemReset`. Kept distinct from
    /// [dismissed] precisely so it can be **omitted from the Flutter wire** —
    /// the flush exists to clear toasts whose Dart sink is already dead.
    case flushed
  }

  /// The toast this event belongs to.
  public let id: String
  public let kind: Kind

  /// Wall-clock milliseconds since the Unix epoch, sampled when the event fired.
  public let timestampMs: Int

  public init(id: String, kind: Kind, timestampMs: Int) {
    self.id = id
    self.kind = kind
    self.timestampMs = timestampMs
  }
}

// MARK: - Listener token

/// Opaque handle for a registered listener; pass it back to
/// `ToastManager.removeEventListener(_:)` to unsubscribe.
public struct ToastEventToken: Hashable, Sendable {
  public let rawValue: Int

  init(_ rawValue: Int) { self.rawValue = rawValue }
}
