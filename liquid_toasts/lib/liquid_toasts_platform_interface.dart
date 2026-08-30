import 'dart:typed_data' show Uint8List;

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'liquid_toasts_method_channel.dart';
import 'src/liquid_toasts_config.dart';
import 'src/toast.dart';
import 'src/toast_event.dart';

/// The platform interface for `liquid_toasts`.
///
/// The Dart facade ([LiquidToasts]) talks only to [instance]; platform
/// implementations (currently the iOS method channel) subclass this.
abstract class LiquidToastsPlatform extends PlatformInterface {
  LiquidToastsPlatform() : super(token: _token);

  static final Object _token = Object();

  static LiquidToastsPlatform _instance = MethodChannelLiquidToasts();

  /// The default instance of [LiquidToastsPlatform] to use.
  static LiquidToastsPlatform get instance => _instance;

  static set instance(LiquidToastsPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Announces a fresh Dart session so native can flush any state left over
  /// from a previous run (e.g. after a hot restart).
  Future<void> handshake(String session) {
    throw UnimplementedError('handshake() has not been implemented.');
  }

  /// Pushes app-wide stack/queue configuration to native.
  Future<void> configure(LiquidToastsConfig config) {
    throw UnimplementedError('configure() has not been implemented.');
  }

  /// Shows [toast] under the Dart-minted [id]. [actionId] correlates the
  /// toast's action button to its Dart callback. Returns whether native
  /// accepted it.
  Future<bool> show(String id, Toast toast, {String? actionId, Uint8List? imageBytes}) {
    throw UnimplementedError('show() has not been implemented.');
  }

  /// Replaces the live toast [id]'s content in place (morph). Returns whether
  /// it was applied (`false` if the toast was already gone — an expected race).
  Future<bool> update(String id, Toast toast, {String? actionId, Uint8List? imageBytes}) {
    throw UnimplementedError('update() has not been implemented.');
  }

  /// Dismisses toast [id]. Returns whether it was live (idempotent).
  Future<bool> dismiss(String id) {
    throw UnimplementedError('dismiss() has not been implemented.');
  }

  /// Dismisses every toast; returns the ids that were actually torn down so the
  /// facade can reconcile its registry in one pass.
  Future<List<String>> dismissAll() {
    throw UnimplementedError('dismissAll() has not been implemented.');
  }

  /// Clears a `loadingOnPress` action's spinner and re-arms the toast's
  /// auto-dismiss without removing it — used when the action's async work
  /// finished but `dismissOnPress` is false (the toast should stay).
  Future<void> finishAction(String id) {
    throw UnimplementedError('finishAction() has not been implemented.');
  }

  /// Test / demo only: simulates an action-button tap natively (drives the
  /// loading spinner + lifecycle for a `loadingOnPress` action) since a real
  /// touch can't be synthesized in an automated reel.
  Future<void> debugTriggerAction(String id) {
    throw UnimplementedError('debugTriggerAction() has not been implemented.');
  }

  /// Advisory device geometry / capability snapshot (Dynamic Island, safe area,
  /// glass mode, …). Native always recomputes real geometry at render time.
  Future<Map<String, dynamic>> queryGeometry() {
    throw UnimplementedError('queryGeometry() has not been implemented.');
  }

  /// Broadcast stream of native → Dart lifecycle events (action taps, body
  /// taps, dismissals), routed by toast id on the Dart side.
  Stream<ToastEvent> get events {
    throw UnimplementedError('events has not been implemented.');
  }
}
