import 'package:liquid_toasts/liquid_toasts.dart';

import 'demo_harness.dart';

/// Demo reel for text layout:
///  1. multiline title only            → centered (compact, no leading/trailing)
///  2. single-line title + multiline body → full-width, left-aligned
///  3. (1) and (2) again, but with a leading icon → left-aligned
///
/// Text is centered only on a compact toast with no leading glyph and no
/// trailing action; a full-width (multiline-body) toast or one with an
/// icon/avatar/action stays left-aligned.
///
/// Record:  tool/record_demo.sh --target lib/text_layout_demo.dart --prefix TEXTALIGN
void main() {
  runDemoReel(
    prefix: 'TEXTALIGN',
    previews: {
      'title-only': _titleOnly,
      'title-and-body': _titleAndBody,
      'title-only-icon': _titleOnlyIcon,
      'title-and-body-icon': _titleAndBodyIcon,
    },
  );
}

const _dur = Duration(milliseconds: 4000);
const _hold = Duration(milliseconds: 1600);
const _longTitle = 'All of your recent changes have been saved successfully';
const _body = 'Your entire photo library is now safely stored in iCloud.';

// 1. Multiline title only, no icon/action → centered.
Future<void> _titleOnly() async {
  toast.raw(const Toast(
    title: _longTitle,
    message: '',
    titleMaxLines: 2,
    duration: _dur,
  ));
  await Future<void>.delayed(_dur + _hold);
}

// 2. Single-line title + multiline body, no icon → full-width, left-aligned.
Future<void> _titleAndBody() async {
  toast.raw(const Toast(
    title: 'Backup complete',
    message: _body,
    maxLines: 2,
    duration: _dur,
  ));
  await Future<void>.delayed(_dur + _hold);
}

// 3a. Multiline title only + icon → left-aligned (leading glyph present).
Future<void> _titleOnlyIcon() async {
  toast.raw(const Toast(
    title: _longTitle,
    message: '',
    icon: 'checkmark.circle.fill',
    semantic: ToastSemantic.success,
    titleMaxLines: 2,
    duration: _dur,
  ));
  await Future<void>.delayed(_dur + _hold);
}

// 3b. Single-line title + multiline body + icon → full-width, left-aligned.
Future<void> _titleAndBodyIcon() async {
  toast.raw(const Toast(
    title: 'Backup complete',
    message: _body,
    icon: 'icloud.fill',
    maxLines: 2,
    duration: _dur,
  ));
  await Future<void>.delayed(_dur + _hold);
}
