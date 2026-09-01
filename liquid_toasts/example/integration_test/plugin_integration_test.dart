// Basic integration test running against the real iOS plugin.
//
// See https://flutter.dev/to/integration-testing

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:liquid_toasts/liquid_toasts.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('queryGeometry returns a device snapshot', (tester) async {
    final geometry = await toast.queryGeometry();
    expect(geometry, isNotEmpty);
    expect(geometry['glassMode'], isA<String>());
  });

  testWidgets('show then dismiss completes the handle', (tester) async {
    final handle = toast.success('Integration test');
    expect(handle.id, isNotEmpty);
    await handle.dismiss();
    final reason = await handle.onDismissed.timeout(
      const Duration(seconds: 3),
      onTimeout: () => ToastDismissReason.unknown,
    );
    expect(reason, isNot(ToastDismissReason.unknown));
  });
}
