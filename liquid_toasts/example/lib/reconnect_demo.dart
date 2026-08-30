import 'package:liquid_toasts/liquid_toasts.dart';

import 'demo_harness.dart';

/// Demo reel for a single use case: a "Trying to reconnect" status toast whose
/// `wifi` SF Symbol animates with the `variableColor` effect — the arcs fill in
/// iteratively and reverse, the classic "trying to connect" motion — while the
/// message holds on screen.
///
/// Record it:  tool/record_demo.sh --target lib/reconnect_demo.dart --prefix RECONNECT
/// Run it:     cd example && flutter run -t lib/reconnect_demo.dart   (iOS 26+ sim)
void main() {
  runDemoReel(
    prefix: 'RECONNECT',
    previews: {
      'reconnecting': _reconnecting,
    },
  );
}

const _hold = Duration(milliseconds: 1700);

// Persistent "Trying to reconnect" toast: the wifi glyph animates its arcs
// (variableColor) for the whole time it's up, then dismisses.
Future<void> _reconnecting() async {
  final handle = toast.show(
    'Trying to reconnect',
    icon: 'wifi',
    style: const ToastStyleOverride(symbolEffect: ToastSymbolEffect.variableColor),
    duration: null,
  );
  // Hold long enough to show several full animation cycles.
  await Future<void>.delayed(const Duration(milliseconds: 5200));
  await handle.dismiss();
  await Future<void>.delayed(_hold);
}
