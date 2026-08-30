import 'package:liquid_toasts/liquid_toasts.dart';

import 'demo_harness.dart';

/// Demo reel for the in-place **shake**: re-showing a toast that shares a
/// `groupKey` with a still-visible one **shakes it on the x-axis** instead of
/// replaying the exit + enter animation — but only when the title/message are
/// unchanged. A re-show that *changes* the text still morphs/replaces as before.
///
/// Record it:  tool/record_demo.sh --target lib/shake_demo.dart --prefix SHAKE
/// Run it:     cd example && flutter run -t lib/shake_demo.dart   (iOS 26+ sim)
void main() {
  runDemoReel(
    prefix: 'SHAKE',
    previews: {
      'copy-link': _copyLink,
      'saved-title': _savedTitle,
      'then-changes': _thenChanges,
    },
  );
}

/// Gap between repeat presses — long enough for each shake to read.
const _beat = Duration(milliseconds: 850);
const _hold = Duration(milliseconds: 1500);

// 1. The classic case: tapping "Copy" again while the confirmation is still up.
// Same text + same groupKey → the toast shakes in place each time instead of
// flashing out and back in.
Future<void> _copyLink() async {
  for (var i = 0; i < 4; i++) {
    toast.success(
      'Link copied',
      groupKey: 'copy',
      duration: const Duration(seconds: 6),
    );
    await Future<void>.delayed(_beat);
  }
  await Future<void>.delayed(_hold);
}

// 2. A titled toast re-triggered — the whole capsule (title + message) shakes.
Future<void> _savedTitle() async {
  for (var i = 0; i < 4; i++) {
    toast.success(
      'Your changes are safe',
      title: 'Saved',
      groupKey: 'save',
      duration: const Duration(seconds: 6),
    );
    await Future<void>.delayed(_beat);
  }
  await Future<void>.delayed(_hold);
}

// 3. Contrast: same groupKey but the text *changes*, so it replaces (morph),
// then an identical re-show shakes — showing both behaviors back to back.
Future<void> _thenChanges() async {
  toast('Uploading…', groupKey: 'upload', duration: const Duration(seconds: 6));
  await Future<void>.delayed(const Duration(milliseconds: 1100));
  // Text changed → replace (not a shake).
  toast.success('Upload complete',
      groupKey: 'upload', duration: const Duration(seconds: 6));
  await Future<void>.delayed(const Duration(milliseconds: 1100));
  // Identical re-shows → shake.
  for (var i = 0; i < 3; i++) {
    toast.success('Upload complete',
        groupKey: 'upload', duration: const Duration(seconds: 6));
    await Future<void>.delayed(_beat);
  }
  await Future<void>.delayed(_hold);
}
