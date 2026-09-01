/// Why a toast left the screen. Wire strings are identical on both sides.
enum ToastDismissReason {
  /// Auto-dismiss duration elapsed.
  timeout,

  /// Programmatic dismissal (`dismiss` / handle.dismiss).
  manual,

  /// User swiped the toast away.
  swipe,

  /// Dismissed as a side effect of the action button (`dismissOnPress`).
  action,

  /// Dismissed by tapping the toast body (`tapToDismiss`).
  tap,

  /// Replaced in place by a same-`groupKey` toast.
  replaced,

  /// Cleared by `dismissAll`.
  dismissAll,

  /// Torn down because the app was backgrounded past the deadline.
  appBackgrounded,

  /// The native event channel was lost; resolved fail-safe on the Dart side.
  channelLost,

  /// Native flushed all toasts (e.g. hot restart handshake).
  systemReset,

  unknown,
}

/// Kind of native → Dart event.
enum ToastEventKind { shown, action, tap, dismissed, unknown }

/// A native → Dart lifecycle event for a single toast, delivered over the
/// broadcast event channel and routed by [id] on the Dart side.
class ToastEvent {
  const ToastEvent({
    required this.id,
    required this.kind,
    this.actionId,
    this.reason = ToastDismissReason.unknown,
    this.stackIndex,
  });

  final String id;
  final ToastEventKind kind;

  /// Set for [ToastEventKind.action]; echoes the action id sent at show time.
  final String? actionId;

  /// Set for [ToastEventKind.dismissed].
  final ToastDismissReason reason;

  /// Set for [ToastEventKind.shown].
  final int? stackIndex;

  factory ToastEvent.fromMap(Map<Object?, Object?> map) => ToastEvent(
        id: (map['id'] as String?) ?? '',
        kind: _kindFromWire(map['event'] as String?),
        actionId: map['actionId'] as String?,
        reason: reasonFromWire(map['reason'] as String?),
        stackIndex: (map['stackIndex'] as num?)?.toInt(),
      );

  static ToastEventKind _kindFromWire(String? value) {
    switch (value) {
      case 'shown':
        return ToastEventKind.shown;
      case 'actionTapped':
        return ToastEventKind.action;
      case 'tapped':
        return ToastEventKind.tap;
      case 'dismissed':
        return ToastEventKind.dismissed;
      default:
        return ToastEventKind.unknown;
    }
  }
}

/// Maps a wire reason string to [ToastDismissReason]. Public so the facade can
/// reuse it when reconciling `dismissAll` results.
ToastDismissReason reasonFromWire(String? value) {
  switch (value) {
    case 'timeout':
      return ToastDismissReason.timeout;
    case 'manual':
      return ToastDismissReason.manual;
    case 'swipe':
      return ToastDismissReason.swipe;
    case 'action':
      return ToastDismissReason.action;
    case 'tap':
      return ToastDismissReason.tap;
    case 'replaced':
      return ToastDismissReason.replaced;
    case 'dismissAll':
      return ToastDismissReason.dismissAll;
    case 'appBackgrounded':
      return ToastDismissReason.appBackgrounded;
    case 'channelLost':
      return ToastDismissReason.channelLost;
    case 'systemReset':
      return ToastDismissReason.systemReset;
    default:
      return ToastDismissReason.unknown;
  }
}
