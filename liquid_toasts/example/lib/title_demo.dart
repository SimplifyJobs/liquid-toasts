import 'package:liquid_toasts/liquid_toasts.dart';

import 'demo_harness.dart';

/// Demo reel for `Toast.titleMaxLines` — a long title now wraps (up to the given
/// number of lines) instead of being truncated to one line with an ellipsis.
///
/// Record:  tool/record_demo.sh --target lib/title_demo.dart --prefix TITLE
void main() {
  runDemoReel(
    prefix: 'TITLE',
    previews: {
      'summary': _summary,
      'comment': _comment,
      'reminder': _reminder,
    },
  );
}

const _hold = Duration(milliseconds: 1600);

// Long title that wraps to 2 lines, in a roomy multiline toast.
Future<void> _summary() async {
  toast.raw(const Toast(
    title: 'Your weekly activity summary is ready to review',
    message: 'See the highlights across all of your projects from the past week.',
    icon: 'chart.bar.fill',
    titleMaxLines: 2,
    maxLines: 2,
    duration: Duration(milliseconds: 4200),
  ));
  await Future<void>.delayed(const Duration(milliseconds: 4200) + _hold);
}

// Two-line title above a wrapping message.
Future<void> _comment() async {
  toast.raw(const Toast(
    title: 'Sarah Chen commented on your latest design proposal',
    message: '“Love the new direction — let’s ship it.” Tap to jump into the thread.',
    icon: 'bubble.left.fill',
    titleMaxLines: 2,
    maxLines: 2,
    duration: Duration(milliseconds: 4200),
  ));
  await Future<void>.delayed(const Duration(milliseconds: 4200) + _hold);
}

// Two-line title in a compact (single-line message) toast.
Future<void> _reminder() async {
  toast.raw(const Toast(
    title: 'Reminder: your team standup starts in five minutes',
    message: 'Tap to join',
    icon: 'calendar',
    semantic: ToastSemantic.info,
    titleMaxLines: 2,
    duration: Duration(milliseconds: 4200),
  ));
  await Future<void>.delayed(const Duration(milliseconds: 4200) + _hold);
}
