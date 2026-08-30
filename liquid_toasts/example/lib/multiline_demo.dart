import 'package:liquid_toasts/liquid_toasts.dart';

import 'demo_harness.dart';

/// Demo reel for the iOS multiline toast layout — long messages that wrap onto
/// more than one line, which trips the native "multiline" treatment (a wider,
/// left-aligned rounded rectangle with roomier insets) instead of the
/// single-line hugging capsule. Two previews carry no action button, two do.
///
/// Each message sets `maxLines >= 2`; the native multiline probe respects
/// `maxLines`, so a long message with `maxLines: 1` would truncate to a capsule
/// and never go multiline.
///
/// Record it:  tool/record_demo.sh --target lib/multiline_demo.dart --prefix MULTILINE
/// Run it:     cd example && flutter run -t lib/multiline_demo.dart   (iOS 26+ sim)
void main() {
  runDemoReel(
    prefix: 'MULTILINE',
    previews: {
      'plain-backup': _plainBackup,
      'titled-update': _titledUpdate,
      'action-archive': _actionArchive,
      'action-software': _actionSoftware,
    },
  );
}

const _hold = Duration(milliseconds: 1700);

// 1. Multiline, no action — a long status message with a leading icon.
Future<void> _plainBackup() async {
  toast.raw(
    const Toast(
      message: 'Backing up your photos to iCloud. This may take a few minutes '
          'while you stay on Wi-Fi.',
      icon: 'icloud.fill',
      maxLines: 3,
      duration: Duration(milliseconds: 4500),
    ),
  );
  await Future<void>.delayed(const Duration(milliseconds: 4500) + _hold);
}

// 2. Multiline, no action — bold title above a wrapping message.
Future<void> _titledUpdate() async {
  toast.raw(
    const Toast(
      title: 'Update installed',
      message: 'Liquid Toasts now lays out long messages on multiple lines for '
          'a roomier, easier read.',
      icon: 'sparkles',
      semantic: ToastSemantic.success,
      maxLines: 3,
      duration: Duration(milliseconds: 4500),
    ),
  );
  await Future<void>.delayed(const Duration(milliseconds: 4500) + _hold);
}

// 3. Multiline, with action — an archive flow with an inline Undo.
Future<void> _actionArchive() async {
  final handle = toast.raw(
    Toast(
      message: 'Your conversation with Alex was moved to Archive. You can find '
          'it anytime in archived chats.',
      icon: 'archivebox.fill',
      maxLines: 3,
      duration: null,
      action: ToastAction(
        label: 'Undo',
        role: ToastActionRole.primary,
        onPressed: () {},
      ),
    ),
  );
  await Future<void>.delayed(const Duration(milliseconds: 4300));
  await handle.dismiss();
  await Future<void>.delayed(_hold);
}

// 4. Multiline, with action — a call-to-action "Update" button.
Future<void> _actionSoftware() async {
  final handle = toast.raw(
    Toast(
      message: 'A new software update is available. It includes important '
          'security fixes and performance improvements.',
      icon: 'arrow.down.circle.fill',
      maxLines: 3,
      duration: null,
      action: ToastAction(
        label: 'Update',
        role: ToastActionRole.primary,
        onPressed: () {},
      ),
    ),
  );
  await Future<void>.delayed(const Duration(milliseconds: 4300));
  await handle.dismiss();
  await Future<void>.delayed(_hold);
}
