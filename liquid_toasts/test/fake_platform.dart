import 'dart:async';
import 'dart:typed_data' show Uint8List;

import 'package:liquid_toasts/liquid_toasts.dart';
import 'package:liquid_toasts/liquid_toasts_platform_interface.dart';

/// A recording fake platform with manual control over the event stream, which
/// toast ids native considers "live", and (optionally) how slowly `show` acks.
class FakeLiquidToastsPlatform extends LiquidToastsPlatform {
  final StreamController<ToastEvent> _events =
      StreamController<ToastEvent>.broadcast();

  final List<String> liveIds = [];

  /// Last toast payload received per id (via `show`).
  final Map<String, Toast> shown = {};

  /// Resolved image bytes received per id (via `show`), null when none.
  final Map<String, Uint8List?> shownImageBytes = {};

  /// Every `update` payload, in arrival order.
  final List<({String id, Toast toast})> updates = [];

  final List<String> finished = [];

  /// Ordered record of show/update/dismiss/dismissAll calls, e.g. `show:lt_x_0001`.
  final List<String> callLog = [];

  bool acceptShows = true;

  /// When set, every `show` waits on it before acking — simulates a slow
  /// native side so in-flight-show races can be tested.
  Completer<void>? showGate;

  List<String> get updatedIds => [for (final u in updates) u.id];

  @override
  Future<void> handshake(String session) async {}

  @override
  Future<void> configure(LiquidToastsConfig config) async {}

  @override
  Future<bool> show(String id, Toast toast,
      {String? actionId, Uint8List? imageBytes}) async {
    if (showGate != null) await showGate!.future;
    callLog.add('show:$id');
    shown[id] = toast;
    shownImageBytes[id] = imageBytes;
    if (acceptShows) liveIds.add(id);
    return acceptShows;
  }

  @override
  Future<bool> update(String id, Toast toast,
      {String? actionId, Uint8List? imageBytes}) async {
    callLog.add('update:$id');
    updates.add((id: id, toast: toast));
    return liveIds.contains(id);
  }

  @override
  Future<bool> dismiss(String id) async {
    callLog.add('dismiss:$id');
    return liveIds.remove(id);
  }

  @override
  Future<void> finishAction(String id) async => finished.add(id);

  @override
  Future<List<String>> dismissAll() async {
    callLog.add('dismissAll');
    final ids = [...liveIds];
    liveIds.clear();
    return ids;
  }

  @override
  Future<Map<String, dynamic>> queryGeometry() async => {};

  @override
  Stream<ToastEvent> get events => _events.stream;

  void emitDismissed(String id, ToastDismissReason reason) {
    liveIds.remove(id);
    toast.debugEmit(
        ToastEvent(id: id, kind: ToastEventKind.dismissed, reason: reason));
  }

  Future<void> dispose() => _events.close();
}
