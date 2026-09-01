import 'dart:async';
import 'dart:typed_data' show Uint8List;

import 'package:flutter/painting.dart' show MemoryImage;
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_toasts/liquid_toasts.dart';
import 'package:liquid_toasts/liquid_toasts_platform_interface.dart';
import 'package:liquid_toasts/src/toast_engine.dart';

import 'fake_platform.dart';

/// A 1×1 transparent PNG (the canonical `kTransparentImage` bytes).
final Uint8List _tinyPng = Uint8List.fromList(const <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, //
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, //
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, //
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeLiquidToastsPlatform fake;

  setUp(() async {
    await toast.debugReset();
    fake = FakeLiquidToastsPlatform();
    LiquidToastsPlatform.instance = fake;
  });

  tearDown(() async {
    await toast.debugReset();
    await fake.dispose();
  });

  group('synchronous show', () {
    test('registers the toast before any await', () {
      final a = toast.success('one');
      final b = toast('two'); // callable shorthand
      expect(toast.activeCount, 2);
      expect(toast.activeIds, containsAll([a.id, b.id]));
      expect(a.id, isNot(b.id));
    });

    test('platform receives the show after the handle exists', () async {
      final t = toast.info('hello');
      expect(fake.shown, isEmpty, reason: 'show is queued, not yet landed');
      await pumpEventQueue();
      expect(fake.shown[t.id]?.message, 'hello');
      expect(fake.shown[t.id]?.semantic, ToastSemantic.info);
    });

    test('update issued before the show lands queues behind it', () async {
      fake.showGate = Completer<void>();
      final t = toast.show('a', duration: null);
      final applied = t.update(message: 'b');
      fake.showGate!.complete();
      expect(await applied, isTrue);
      expect(fake.callLog, ['show:${t.id}', 'update:${t.id}']);
      expect(fake.updates.single.toast.message, 'b');
    });

    test('rejected show completes the handle with channelLost', () async {
      fake.acceptShows = false;
      final t = toast.show('x');
      expect(await t.onDismissed, ToastDismissReason.channelLost);
      expect(await t.update(message: 'y'), isFalse);
      expect(toast.activeCount, 0);
    });
  });

  group('patch updates', () {
    test('rapid patches compose off each other before either lands', () async {
      final t = toast.show('up', duration: null, progress: 0);
      unawaited(t.update(progress: 0.3));
      final done = t.update(message: 'almost');
      await done;
      expect(fake.updates, hasLength(2));
      expect(fake.updates[0].toast.progress, 0.3);
      expect(fake.updates[0].toast.message, 'up');
      // Second patch composes off the first (progress kept), not off the show.
      expect(fake.updates[1].toast.progress, 0.3);
      expect(fake.updates[1].toast.message, 'almost');
    });

    test('patch can morph a loading toast into a static one', () async {
      final t = toast.loading('Working…');
      await pumpEventQueue();
      expect(fake.shown[t.id]?.loading, isTrue);
      await t.update(
          loading: false,
          message: 'Done',
          semantic: ToastSemantic.success,
          duration: const Duration(seconds: 2));
      final morphed = fake.updates.single.toast;
      expect(morphed.loading, isFalse);
      expect(morphed.message, 'Done');
      expect(morphed.isPersistent, isFalse);
    });

    test('replace swaps content wholesale (clears unspecified fields)',
        () async {
      final t = toast.show('m', title: 'T', duration: null);
      await t.replace(const Toast(message: 'm2', duration: null));
      expect(fake.updates.single.toast.title, isNull);
      expect(fake.updates.single.toast.message, 'm2');
    });
  });

  group('durations', () {
    test('omitted duration uses the per-semantic default', () async {
      final ok = toast.success('s');
      final bad = toast.error('e');
      await pumpEventQueue();
      expect(fake.shown[ok.id]?.duration, const Duration(seconds: 3));
      expect(fake.shown[bad.id]?.duration, const Duration(seconds: 4));
    });

    test('explicit null means persistent (no silent coercion)', () async {
      final t = toast.success('s', duration: null);
      await pumpEventQueue();
      expect(fake.shown[t.id]?.isPersistent, isTrue);
    });

    test('setDefaults duration and position propagate to convenience shows',
        () async {
      await toast.setDefaults(const LiquidToastsConfig(
        defaultPosition: ToastPosition.bottomCenter,
        defaultDuration: Duration(seconds: 10),
      ));
      final t = toast.info('x');
      await pumpEventQueue();
      final sent = fake.shown[t.id]!;
      expect(sent.position, ToastPosition.bottomCenter);
      expect(sent.duration, const Duration(seconds: 10));
    });

    test('a raw Toast without position gets the app default', () async {
      await toast.setDefaults(const LiquidToastsConfig(
          defaultPosition: ToastPosition.bottomTrailing));
      final t = toast.raw(const Toast(message: 'x'));
      await pumpEventQueue();
      expect(fake.shown[t.id]?.position, ToastPosition.bottomTrailing);
    });
  });

  group('global line limits', () {
    test('apply to convenience, raw, and promise-created toasts', () async {
      await toast.setDefaults(
        const LiquidToastsConfig(maxLines: 3, titleMaxLines: 2),
      );

      final convenience = toast.warning('warning', title: 'title');
      final raw = toast.raw(const Toast(message: 'raw', title: 'title'));
      final promise = toast.promise<void>(
        Future<void>.value(),
        loading: 'loading',
        success: 'done',
      );
      await promise;

      expect(fake.shown[convenience.id]?.maxLines, 3);
      expect(fake.shown[convenience.id]?.titleMaxLines, 2);
      expect(fake.shown[raw.id]?.maxLines, 3);
      expect(fake.shown[raw.id]?.titleMaxLines, 2);
      expect(fake.updates.single.toast.maxLines, 3);
      expect(fake.updates.single.toast.titleMaxLines, 2);
    });

    test('per-toast values override the global settings', () async {
      await toast.setDefaults(
        const LiquidToastsConfig(maxLines: 4, titleMaxLines: 3),
      );
      final t = toast.show(
        'message',
        title: 'title',
        maxLines: 1,
        titleMaxLines: 1,
      );
      await pumpEventQueue();

      expect(fake.shown[t.id]?.maxLines, 1);
      expect(fake.shown[t.id]?.titleMaxLines, 1);
    });

    test('null settings preserve the semantic message defaults', () async {
      final warning = toast.warning('warning');
      final info = toast.info('info');
      await pumpEventQueue();

      expect(fake.shown[warning.id]?.maxLines, 2);
      expect(fake.shown[info.id]?.maxLines, 1);
      expect(fake.shown[warning.id]?.titleMaxLines, 1);
    });
  });

  group('promise', () {
    test('returns the value and morphs to a built success toast', () async {
      final completer = Completer<int>();
      final future = toast.promise<int>(
        completer.future,
        loading: 'working',
        success: (int v) => 'got $v',
      );
      await pumpEventQueue();
      expect(toast.activeCount, 1, reason: 'spinner shown');
      completer.complete(42);
      expect(await future, 42);
      final morph = fake.updates.single.toast;
      expect(morph.message, 'got 42');
      expect(morph.semantic, ToastSemantic.success);
    });

    test('accepts String and Toast specs', () async {
      final future = toast.promise<int>(
        Future.value(1),
        loading: 'w',
        success: Toast.success(message: 'custom'),
      );
      expect(await future, 1);
      expect(fake.updates.single.toast.message, 'custom');
    });

    test('rethrows and morphs to error; String error spec wins', () async {
      final completer = Completer<int>();
      final future = toast.promise<int>(
        completer.future,
        loading: 'w',
        error: 'failed hard',
      );
      completer.completeError(StateError('boom'));
      await expectLater(future, throwsA(isA<StateError>()));
      final morph = fake.updates.single.toast;
      expect(morph.message, 'failed hard');
      expect(morph.semantic, ToastSemantic.error);
    });

    test('default error message uses errorMessageResolver', () async {
      toast.errorMessageResolver = (e) => 'friendly';
      final future = toast.promise<int>(
        Future<int>.error(StateError('internal')),
        loading: 'w',
      );
      await expectLater(future, throwsA(isA<StateError>()));
      expect(fake.updates.single.toast.message, 'friendly');
    });

    test('invalid specs throw ArgumentError eagerly, before the future',
        () {
      final never = Completer<int>().future;
      expect(() => toast.promise<int>(never, success: 42), throwsArgumentError);
      expect(() => toast.promise<int>(never, error: 1.5), throwsArgumentError);
      expect(() => toast.promise<int>(never, loading: 7), throwsArgumentError);
      expect(toast.activeCount, 0, reason: 'no spinner leaked');
    });

    test('dismissed mid-flight still delivers the value, skips the morph',
        () async {
      final completer = Completer<int>();
      final future = toast.promise<int>(completer.future, loading: 'w');
      await pumpEventQueue();
      fake.emitDismissed(toast.activeIds.single, ToastDismissReason.swipe);
      completer.complete(7);
      expect(await future, 7);
      expect(fake.updates, isEmpty);
    });

    test('a throwing success builder never corrupts the returned value',
        () async {
      final future = toast.promise<int>(
        Future.value(9),
        loading: 'w',
        success: (int v) => throw StateError('builder bug'),
      );
      expect(await future, 9);
      expect(fake.updates, isEmpty, reason: 'morph skipped, toast dismissed');
    });
  });

  group('leading images', () {
    test('a decodable image resolves to PNG bytes on the wire', () async {
      final t = toast.show('pic', leadingImage: MemoryImage(_tinyPng));
      await ToastEngine.instance.settle(t.id);
      expect(fake.shown[t.id], isNotNull);
      expect(fake.shownImageBytes[t.id], isNotNull);
    });

    test('a failing image is logged and the toast shows without bytes',
        () async {
      final t = toast.show('pic',
          leadingImage: MemoryImage(Uint8List.fromList([1, 2, 3])));
      await ToastEngine.instance.settle(t.id);
      expect(fake.shown[t.id], isNotNull, reason: 'toast still shows');
      expect(fake.shownImageBytes[t.id], isNull);
    });

    test('toasts without an image skip the pipeline entirely', () async {
      final t = toast.show('plain');
      await ToastEngine.instance.settle(t.id);
      expect(fake.shownImageBytes[t.id], isNull);
    });
  });

  group('lifecycle', () {
    test('dismissAll chases a show that lands after it', () async {
      fake.showGate = Completer<void>();
      final t = toast.show('late', duration: null);
      await toast.dismissAll();
      expect(await t.onDismissed, ToastDismissReason.dismissAll);
      fake.showGate!.complete(); // the show lands natively only now
      await pumpEventQueue();
      final showIndex = fake.callLog.indexOf('show:${t.id}');
      final dismissIndex = fake.callLog.indexOf('dismiss:${t.id}');
      expect(showIndex, isNonNegative);
      expect(dismissIndex, greaterThan(showIndex),
          reason: 'orphaned native toast is chased down');
      expect(fake.liveIds, isEmpty);
    });

    test('an update supersedes an in-flight async action (generation)',
        () async {
      final gate = Completer<void>();
      final t = toast.show(
        'x',
        duration: null,
        action: ToastAction(
          label: 'Go',
          loadingOnPress: true,
          onPressed: () => gate.future,
        ),
      );
      await pumpEventQueue();
      toast.debugEmit(
          ToastEvent(id: t.id, kind: ToastEventKind.action, actionId: null));
      await t.update(message: 'newer'); // supersedes the running action
      gate.complete();
      await pumpEventQueue();
      expect(fake.liveIds, contains(t.id),
          reason: 'stale action completion must not dismiss the newer content');
      expect(fake.finished, isEmpty);
    });

    test('lost event channel fail-safe completes pending handles', () async {
      final t = toast.show('persist', duration: null);
      await pumpEventQueue();
      await fake.dispose();
      final reason = await t.onDismissed.timeout(
        const Duration(seconds: 1),
        onTimeout: () => ToastDismissReason.unknown,
      );
      expect(reason, ToastDismissReason.channelLost);
    });
  });
}
