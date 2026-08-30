import 'package:flutter/services.dart';

import 'liquid_toasts_platform_interface.dart';
import 'src/liquid_toasts_config.dart';
import 'src/toast.dart';
import 'src/toast_event.dart';

/// Method/event-channel implementation of [LiquidToastsPlatform].
///
/// Commands go over the `liquid_toasts` [MethodChannel]; native → Dart events
/// arrive on the `liquid_toasts/events` broadcast [EventChannel].
class MethodChannelLiquidToasts extends LiquidToastsPlatform {
  /// Bumped if the wire format changes incompatibly; native rejects mismatches.
  static const int protocolVersion = 1;

  final MethodChannel methodChannel = const MethodChannel('liquid_toasts');
  final EventChannel _eventChannel = const EventChannel('liquid_toasts/events');

  Stream<ToastEvent>? _events;

  Map<String, Object?> _envelope(Map<String, Object?> body) => {
        'protocolVersion': protocolVersion,
        ...body,
      };

  @override
  Future<void> handshake(String session) => methodChannel.invokeMethod<void>(
        'handshake',
        _envelope({'session': session}),
      );

  @override
  Future<void> configure(LiquidToastsConfig config) =>
      methodChannel.invokeMethod<void>(
        'configure',
        _envelope(config.toMap()),
      );

  @override
  Future<bool> show(String id, Toast toast, {String? actionId, Uint8List? imageBytes}) async {
    final res = await methodChannel.invokeMapMethod<String, Object?>(
      'show',
      _envelope({'id': id, ...toast.toMap(actionId: actionId, imageBytes: imageBytes)}),
    );
    return (res?['accepted'] as bool?) ?? true;
  }

  @override
  Future<bool> update(String id, Toast toast, {String? actionId, Uint8List? imageBytes}) async {
    final res = await methodChannel.invokeMapMethod<String, Object?>(
      'update',
      _envelope({'id': id, ...toast.toMap(actionId: actionId, imageBytes: imageBytes)}),
    );
    return (res?['applied'] as bool?) ?? false;
  }

  @override
  Future<bool> dismiss(String id) async {
    final res = await methodChannel.invokeMapMethod<String, Object?>(
      'dismiss',
      _envelope({'id': id, 'animated': true}),
    );
    return (res?['dismissed'] as bool?) ?? false;
  }

  @override
  Future<List<String>> dismissAll() async {
    final res = await methodChannel.invokeMapMethod<String, Object?>(
      'dismissAll',
      _envelope({'animated': true, 'reason': 'dismissAll'}),
    );
    final ids = res?['dismissedIds'] as List<Object?>?;
    return ids?.cast<String>() ?? const <String>[];
  }

  @override
  Future<void> finishAction(String id) => methodChannel.invokeMethod<void>(
        'finishAction',
        _envelope({'id': id}),
      );

  @override
  Future<void> debugTriggerAction(String id) => methodChannel.invokeMethod<void>(
        'debugTriggerAction',
        _envelope({'id': id}),
      );

  @override
  Future<Map<String, dynamic>> queryGeometry() async {
    final res = await methodChannel.invokeMapMethod<String, Object?>(
      'queryGeometry',
      _envelope(const {}),
    );
    return res?.cast<String, dynamic>() ?? <String, dynamic>{};
  }

  @override
  Stream<ToastEvent> get events => _events ??= _eventChannel
      .receiveBroadcastStream()
      .map((dynamic e) => ToastEvent.fromMap((e as Map).cast<Object?, Object?>()));
}
