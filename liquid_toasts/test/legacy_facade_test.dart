// Smoke coverage that the deprecated LiquidToasts facade keeps working as
// thin delegates over the engine until its removal in 1.0.
// ignore_for_file: deprecated_member_use_from_same_package

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_toasts/liquid_toasts.dart';
import 'package:liquid_toasts/liquid_toasts_method_channel.dart';
import 'package:liquid_toasts/liquid_toasts_platform_interface.dart';

import 'fake_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeLiquidToastsPlatform fake;

  setUp(() async {
    await LiquidToasts.debugReset();
    fake = FakeLiquidToastsPlatform();
    LiquidToastsPlatform.instance = fake;
  });

  tearDown(() async {
    await LiquidToasts.debugReset();
    await fake.dispose();
  });

  test('method channel is a valid platform implementation', () {
    expect(MethodChannelLiquidToasts(), isA<LiquidToastsPlatform>());
  });

  test('show registers a tracked toast with a unique id', () async {
    final a = await LiquidToasts.success('one');
    final b = await LiquidToasts.success('two');
    expect(a.id, isNot(b.id));
    expect(LiquidToasts.activeCount, 2);
    expect(LiquidToasts.activeIds, containsAll([a.id, b.id]));
  });

  test('show resolves only after the platform ack (legacy contract)',
      () async {
    final handle = await LiquidToasts.error('boom');
    expect(fake.shown[handle.id]?.message, 'boom');
    expect(fake.shown[handle.id]?.duration, const Duration(seconds: 4));
  });

  test('warning and info delegate with their semantic defaults', () async {
    final w = await LiquidToasts.warning('careful');
    final i = await LiquidToasts.info('fyi');
    expect(fake.shown[w.id]?.semantic, ToastSemantic.warning);
    expect(fake.shown[i.id]?.semantic, ToastSemantic.info);
  });

  test('dismissed event completes the handle and frees the registration',
      () async {
    final handle = await LiquidToasts.show(const Toast(message: 'hi'));
    expect(handle.isShowing, isTrue);
    fake.emitDismissed(handle.id, ToastDismissReason.timeout);
    expect(await handle.onDismissed, ToastDismissReason.timeout);
    expect(handle.isDismissed, isTrue);
    expect(LiquidToasts.activeCount, 0);
  });

  test('action tap fires onPressed; a stale actionId is dropped', () async {
    var taps = 0;
    final handle = await LiquidToasts.show(Toast(
      message: 'with action',
      duration: null,
      action: ToastAction(label: 'Go', onPressed: () => taps++),
    ));

    // Wrong/stale actionId -> ignored.
    LiquidToasts.debugEmit(ToastEvent(
        id: handle.id, kind: ToastEventKind.action, actionId: 'stale'));
    expect(taps, 0);

    // null actionId is treated as a match -> fires.
    LiquidToasts.debugEmit(ToastEvent(
        id: handle.id, kind: ToastEventKind.action, actionId: null));
    expect(taps, 1);
  });

  test('async action (loadingOnPress) runs onPressed then dismisses', () async {
    var ran = false;
    final handle = await LiquidToasts.show(Toast(
      message: 'x',
      duration: null,
      action: ToastAction(
        label: 'Go',
        loadingOnPress: true,
        onPressed: () async {
          ran = true;
        },
      ),
    ));
    LiquidToasts.debugEmit(ToastEvent(
        id: handle.id, kind: ToastEventKind.action, actionId: null));
    await Future<void>.delayed(Duration.zero);
    expect(ran, isTrue);
    expect(fake.liveIds, isNot(contains(handle.id))); // dismissed on completion
    expect(fake.finished, isEmpty);
  });

  test('async action with dismissOnPress:false finishes without dismissing',
      () async {
    var ran = false;
    final handle = await LiquidToasts.show(Toast(
      message: 'x',
      duration: null,
      action: ToastAction(
        label: 'Go',
        loadingOnPress: true,
        dismissOnPress: false,
        onPressed: () async {
          ran = true;
        },
      ),
    ));
    LiquidToasts.debugEmit(ToastEvent(
        id: handle.id, kind: ToastEventKind.action, actionId: null));
    await Future<void>.delayed(Duration.zero);
    expect(ran, isTrue);
    expect(fake.finished, contains(handle.id)); // spinner cleared, toast kept
    expect(fake.liveIds, contains(handle.id)); // not dismissed
  });

  test('showLoading returns the value and morphs to success', () async {
    final completer = Completer<int>();
    final future = LiquidToasts.showLoading<int>(
      completer.future,
      config: const LoadingToast(loadingMessage: 'working'),
    );
    await Future<void>.delayed(Duration.zero);
    expect(LiquidToasts.activeCount, 1, reason: 'spinner shown');
    completer.complete(42);
    expect(await future, 42);
    expect(fake.updatedIds.length, 1, reason: 'morphed loading -> success');
  });

  test('showLoading rethrows and morphs to error', () async {
    final completer = Completer<int>();
    final future = LiquidToasts.showLoading<int>(
      completer.future,
      config: const LoadingToast(loadingMessage: 'working'),
    );
    await Future<void>.delayed(Duration.zero);
    completer.completeError(StateError('boom'));
    await expectLater(future, throwsA(isA<StateError>()));
    expect(fake.updatedIds.length, 1, reason: 'morphed loading -> error');
  });

  test('showLoading honors the global errorMessageResolver', () async {
    LiquidToasts.errorMessageResolver = (e) => 'friendly';
    final future = LiquidToasts.showLoading<int>(
      Future<int>.error(StateError('internal')),
      config: const LoadingToast(loadingMessage: 'working'),
    );
    await expectLater(future, throwsA(isA<StateError>()));
    expect(fake.updates.single.toast.message, 'friendly');
  });

  test('loading dismissed mid-flight still delivers the value, skips update',
      () async {
    final completer = Completer<int>();
    final future = LiquidToasts.showLoading<int>(
      completer.future,
      config: const LoadingToast(loadingMessage: 'working'),
    );
    await Future<void>.delayed(Duration.zero);
    final id = LiquidToasts.activeIds.single;
    fake.emitDismissed(id, ToastDismissReason.swipe);
    completer.complete(7);
    expect(await future, 7, reason: 'outcome delivered despite dismissal');
    expect(fake.updatedIds, isEmpty, reason: 'no update on a gone toast');
  });

  test('two overlapping loading toasts resolve independently in any order',
      () async {
    final a = Completer<String>();
    final b = Completer<String>();
    final fa = LiquidToasts.showLoading<String>(a.future,
        config: const LoadingToast(loadingMessage: 'a'));
    final fb = LiquidToasts.showLoading<String>(b.future,
        config: const LoadingToast(loadingMessage: 'b'));
    await Future<void>.delayed(Duration.zero);
    expect(LiquidToasts.activeCount, 2);
    b.complete('B');
    a.complete('A');
    expect(await fb, 'B');
    expect(await fa, 'A');
  });

  test('dismissAll reconciles every handle via returned ids', () async {
    final h1 =
        await LiquidToasts.show(const Toast(message: '1', duration: null));
    final h2 =
        await LiquidToasts.show(const Toast(message: '2', duration: null));
    await LiquidToasts.dismissAll();
    expect(await h1.onDismissed, ToastDismissReason.dismissAll);
    expect(await h2.onDismissed, ToastDismissReason.dismissAll);
    expect(LiquidToasts.activeCount, 0);
  });

  test('dismiss of an already-gone toast completes the handle locally',
      () async {
    final handle =
        await LiquidToasts.show(const Toast(message: 'x', duration: null));
    fake.liveIds.clear(); // native dropped it without an event
    await handle.dismiss();
    expect(await handle.onDismissed, ToastDismissReason.manual);
  });

  test('setDefaults reaches the convenience methods', () async {
    await LiquidToasts.setDefaults(const LiquidToastsConfig(
      defaultDuration: Duration(seconds: 9),
    ));
    final h = await LiquidToasts.success('x');
    expect(fake.shown[h.id]?.duration, const Duration(seconds: 9));
  });

  test('lost event channel fail-safe completes pending handles', () async {
    final handle = await LiquidToasts
        .show(const Toast(message: 'persist', duration: null));
    await fake.dispose(); // closing the stream triggers onDone
    final reason = await handle.onDismissed.timeout(
      const Duration(seconds: 1),
      onTimeout: () => ToastDismissReason.unknown,
    );
    expect(reason, ToastDismissReason.channelLost);
  });
}
