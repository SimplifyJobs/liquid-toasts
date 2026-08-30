import 'package:flutter/painting.dart' show EdgeInsets;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_toasts/liquid_toasts.dart';
import 'package:liquid_toasts/liquid_toasts_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final MethodChannelLiquidToasts platform = MethodChannelLiquidToasts();
  const MethodChannel channel = MethodChannel('liquid_toasts');
  final List<MethodCall> calls = [];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      calls.add(methodCall);
      switch (methodCall.method) {
        case 'show':
          return {'id': methodCall.arguments['id'], 'accepted': true};
        case 'update':
          return {'applied': true};
        case 'dismiss':
          return {'dismissed': true};
        case 'dismissAll':
          return {
            'dismissedIds': ['lt_x_0000']
          };
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('show serializes the toast and parses the ack', () async {
    final accepted = await platform.show(
      'lt_x_0001',
      Toast.success(message: 'Saved', icon: 'checkmark'),
      actionId: null,
    );
    expect(accepted, isTrue);

    final call = calls.single;
    expect(call.method, 'show');
    final args = call.arguments as Map;
    expect(args['protocolVersion'], 1);
    expect(args['id'], 'lt_x_0001');
    expect(args['message'], 'Saved');
    expect(args['icon'], 'checkmark');
    expect(args['semantic'], 'success');
    expect(args['state'], 'static');
    expect(args['position'], 'topCenter');
  });

  test('loading toast serializes as persistent with state=loading', () {
    final map = Toast.loading(message: 'Working').toMap();
    expect(map['state'], 'loading');
    expect(map['persistent'], true);
    expect(map.containsKey('durationMs'), isFalse);
  });

  test('action serializes the actionId and role', () {
    final map = Toast(
      message: 'x',
      action: ToastAction(
          label: 'Retry',
          role: ToastActionRole.destructive,
          onPressed: () {}),
    ).toMap(actionId: 'a7');
    final action = map['action'] as Map;
    expect(action['actionId'], 'a7');
    expect(action['role'], 'destructive');
    expect(action['label'], 'Retry');
  });

  test('dismissAll parses the dismissedIds list', () async {
    final ids = await platform.dismissAll();
    expect(ids, ['lt_x_0000']);
  });

  test('update parses the applied ack and envelopes the payload', () async {
    final applied = await platform.update(
      'lt_x_0002',
      const Toast(message: 'now'),
    );
    expect(applied, isTrue);
    final args = calls.single.arguments as Map;
    expect(args['protocolVersion'], 1);
    expect(args['id'], 'lt_x_0002');
  });

  test('dismiss parses the dismissed ack', () async {
    expect(await platform.dismiss('lt_x_0003'), isTrue);
    final args = calls.single.arguments as Map;
    expect(args['id'], 'lt_x_0003');
    expect(args['animated'], isTrue);
  });

  test('missing acks fall back safely (show accepts, update/dismiss reject)',
      () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => null);
    expect(await platform.show('id', const Toast(message: 'x')), isTrue);
    expect(await platform.update('id', const Toast(message: 'x')), isFalse);
    expect(await platform.dismiss('id'), isFalse);
    expect(await platform.dismissAll(), isEmpty);
  });

  test('a raw Toast without a position serializes the topCenter fallback', () {
    expect(const Toast(message: 'x').toMap()['position'], 'topCenter');
  });

  test('configure serializes the custom safe area in logical pixels', () async {
    await platform.configure(
      const LiquidToastsConfig(safeArea: EdgeInsets.fromLTRB(12, 96, 20, 72)),
    );

    final args = calls.single.arguments as Map;
    expect(args['protocolVersion'], 1);
    expect(args['safeArea'], {
      'left': 12.0,
      'top': 96.0,
      'right': 20.0,
      'bottom': 72.0,
    });
  });
}
