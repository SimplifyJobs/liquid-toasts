import 'package:liquid_toasts/liquid_toasts.dart';

import 'demo_harness.dart';

/// Auto-playing showcase reel for the Android demo recording. Plays a sequence
/// of short, high-contrast previews over the full-bleed wallpaper so the Liquid
/// Glass toasts have something to refract. Each preview shows one or two toasts
/// that read well on video, then clears before the next.
///
/// Follows the same marker contract as the other reels (see [runDemoReel]):
///
///   `ANDSHOW:<name>:START`   `ANDSHOW:<name>:END`   …   `ANDSHOW:DONE`
///
/// Record:  tool/record_demo.sh --target lib/android_showcase.dart --prefix ANDSHOW
/// Run it:  cd example && flutter run -t lib/android_showcase.dart
void main() {
  runDemoReel(
    prefix: 'ANDSHOW',
    previews: {
      'success-title': _successTitle,
      'error-multiline': _errorMultiline,
      'action-undo': _actionUndo,
      'promise-morph': _promiseMorph,
      'progress-bar': _progressBar,
      'stack-three': _stackThree,
      'groupkey-replace': _groupKeyReplace,
    },
  );
}

/// Extra beat a finished toast lingers before the reel clears the screen.
const _hold = Duration(milliseconds: 1600);

// 1. Success toast with a bold title — the happy path.
Future<void> _successTitle() async {
  toast.success(
    'Your changes are now live for everyone.',
    title: 'Published',
    duration: const Duration(milliseconds: 3200),
  );
  await Future<void>.delayed(const Duration(milliseconds: 3200) + _hold);
}

// 2. Multiline error toast — a wrapping message with a leading icon.
Future<void> _errorMultiline() async {
  toast.error(
    'We couldn’t reach the server. Your work is saved locally and will sync '
    'once you’re back online.',
    title: 'Sync failed',
    maxLines: 3,
    duration: const Duration(milliseconds: 3800),
  );
  await Future<void>.delayed(const Duration(milliseconds: 3800) + _hold);
}

// 3. Toast with an inline action button (Undo), dismissed on the reel's clock.
Future<void> _actionUndo() async {
  final handle = toast.raw(
    Toast(
      message: 'Conversation archived',
      icon: 'archivebox.fill',
      duration: null,
      action: ToastAction(
        label: 'Undo',
        role: ToastActionRole.primary,
        onPressed: () {},
      ),
    ),
  );
  await Future<void>.delayed(const Duration(milliseconds: 3400));
  await handle.dismiss();
  await Future<void>.delayed(_hold);
}

// 4. Loading → success morph via toast.promise.
Future<void> _promiseMorph() async {
  await toast.promise<void>(
    Future<void>.delayed(const Duration(milliseconds: 2200)),
    loading: 'Syncing your library…',
    success: 'Library synced',
  );
  await Future<void>.delayed(_hold);
}

// 5. Linear progress bar filling 0 → 1, then a hugging "done" capsule.
Future<void> _progressBar() async {
  final handle = toast.raw(const Toast(
    title: 'Downloading',
    message: 'season-2.zip',
    icon: 'arrow.down.circle',
    maxLines: 2,
    duration: null,
    progress: 0,
  ));
  for (var p = 1; p <= 10; p++) {
    await Future<void>.delayed(const Duration(milliseconds: 220));
    await handle.update(progress: p / 10);
  }
  await handle.replace(const Toast(
    message: 'Download complete',
    icon: 'checkmark.circle.fill',
    semantic: ToastSemantic.success,
    duration: Duration(seconds: 2),
  ));
  await Future<void>.delayed(const Duration(seconds: 2) + _hold);
}

// 6. Three toasts stacking at the bottom center.
Future<void> _stackThree() async {
  for (var i = 1; i <= 3; i++) {
    toast.info(
      'Notification #$i',
      position: ToastPosition.bottomCenter,
      duration: const Duration(milliseconds: 3400),
    );
    await Future<void>.delayed(const Duration(milliseconds: 320));
  }
  await Future<void>.delayed(const Duration(milliseconds: 3400) + _hold);
}

// 7. Same groupKey shown repeatedly — replaces in place instead of stacking.
Future<void> _groupKeyReplace() async {
  for (var i = 1; i <= 3; i++) {
    toast.info(
      'Message from Alex ($i)',
      icon: 'bubble.left.fill',
      groupKey: 'inbox',
      duration: const Duration(milliseconds: 3200),
    );
    await Future<void>.delayed(const Duration(milliseconds: 800));
  }
  await Future<void>.delayed(const Duration(milliseconds: 2600) + _hold);
}
