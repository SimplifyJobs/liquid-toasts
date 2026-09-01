import 'package:liquid_toasts/liquid_toasts.dart';

import 'demo_harness.dart';

/// Demo reel for the newer toast features:
///  • a determinate **linear** progress bar that fills the width of a multiline toast
///  • a determinate **circular** progress ring in the leading slot
///  • an action button on a multiline toast
///
/// Auto-dismiss also **pauses while a toast is being touched** (held / dragged)
/// and resumes on release — that's interaction-driven, so it isn't part of this
/// auto-played reel (touch-and-hold a real toast to see the countdown hold).
///
/// Record:  tool/record_demo.sh --target lib/features_demo.dart --prefix FEATURES
void main() {
  runDemoReel(
    prefix: 'FEATURES',
    previews: {
      'progress-linear': _progressLinear,
      'progress-circular': _progressCircular,
      'action-multiline': _actionMultiline,
    },
  );
}

const _hold = Duration(milliseconds: 1500);

// 1. Multiline toast whose linear progress bar fills the full toast width.
Future<void> _progressLinear() async {
  const message = 'Uploading your photo library to iCloud — keep the app open '
      'until this finishes.';
  final handle = toast.raw(const Toast(
    title: 'Backing up',
    message: message,
    icon: 'icloud.fill',
    maxLines: 2,
    duration: null,
    progress: 0,
  ));
  for (var p = 1; p <= 10; p++) {
    await Future<void>.delayed(const Duration(milliseconds: 230));
    await handle.replace(Toast(
      title: 'Backing up',
      message: message,
      icon: 'icloud.fill',
      maxLines: 2,
      duration: null,
      progress: p / 10,
    ));
  }
  // One-liner done state: morphs from the wide multiline progress toast down to
  // a hugging single-line capsule (animated, not snapped).
  await handle.replace(const Toast(
    message: 'Backed up to iCloud',
    icon: 'checkmark.circle.fill',
    semantic: ToastSemantic.success,
    duration: Duration(seconds: 2),
  ));
  await Future<void>.delayed(const Duration(seconds: 2) + _hold);
}

// 2. Determinate circular progress ring in the leading slot.
Future<void> _progressCircular() async {
  final handle = toast.raw(const Toast(
    message: 'Downloading season 2',
    duration: null,
    progress: 0,
    progressStyle: ToastProgressStyle.circular,
  ));
  for (var p = 1; p <= 10; p++) {
    await Future<void>.delayed(const Duration(milliseconds: 230));
    await handle.replace(Toast(
      message: 'Downloading season 2',
      duration: null,
      progress: p / 10,
      progressStyle: ToastProgressStyle.circular,
    ));
  }
  await handle.replace(const Toast(
    message: 'Download complete',
    icon: 'checkmark.circle.fill',
    semantic: ToastSemantic.success,
    duration: Duration(seconds: 2),
  ));
  await Future<void>.delayed(const Duration(seconds: 2) + _hold);
}

// 3. Multiline toast with an action button (the text column yields to the button).
Future<void> _actionMultiline() async {
  final handle = toast.raw(Toast(
    message: 'Your conversation with Alex was moved to Archive. You can find it '
        'anytime in archived chats.',
    icon: 'archivebox.fill',
    maxLines: 3,
    duration: null,
    action: ToastAction(
      label: 'Undo',
      role: ToastActionRole.primary,
      onPressed: () {},
    ),
  ));
  await Future<void>.delayed(const Duration(milliseconds: 4300));
  await handle.dismiss();
  await Future<void>.delayed(_hold);
}
