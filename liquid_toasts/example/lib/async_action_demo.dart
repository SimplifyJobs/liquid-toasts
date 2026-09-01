import 'package:liquid_toasts/liquid_toasts.dart';

import 'demo_harness.dart';

/// Demo reel for async action buttons (`ToastAction.loadingOnPress`).
///
/// When the button is pressed its label is replaced by a spinner and the toast
/// stays up until the (async) `onPressed` future resolves — then it dismisses.
///
/// An automated reel can't synthesize a real touch, so each preview shows the
/// toast and then calls `toast.debugTriggerAction` to fire the button
/// exactly as a tap would (spinner → await onPressed → dismiss).
///
/// Record:  tool/record_demo.sh --target lib/async_action_demo.dart --prefix ASYNCACTION
void main() {
  runDemoReel(
    prefix: 'ASYNCACTION',
    previews: {
      'approve': _approve,
      'save': _save,
      'delete': _delete,
    },
  );
}

const _hold = Duration(milliseconds: 1500);

/// A pretend network call the action awaits.
Future<void> _work() => Future<void>.delayed(const Duration(milliseconds: 1700));

Future<void> _run(Toast spec) async {
  final handle = toast.raw(spec);
  await Future<void>.delayed(const Duration(milliseconds: 900)); // button idle
  // No real touch in an automated reel — fire the button as a tap would.
  // ignore: invalid_use_of_visible_for_testing_member
  await toast.debugTriggerAction(handle.id); // spinner → await onPressed → dismiss
  await handle.onDismissed;
  await Future<void>.delayed(_hold);
}

Future<void> _approve() => _run(Toast(
      message: 'Approve Alex’s time-off request?',
      icon: 'calendar.badge.clock',
      duration: null,
      action: ToastAction(
        label: 'Approve',
        role: ToastActionRole.success,
        loadingOnPress: true,
        onPressed: _work,
      ),
    ));

Future<void> _save() => _run(Toast(
      message: 'Save changes to your profile?',
      icon: 'square.and.pencil',
      duration: null,
      action: ToastAction(
        label: 'Save',
        loadingOnPress: true,
        onPressed: _work,
      ),
    ));

Future<void> _delete() => _run(Toast(
      message: 'Delete “Q3 report.pdf”? This can’t be undone.',
      icon: 'trash',
      maxLines: 2,
      duration: null,
      action: ToastAction(
        label: 'Delete',
        role: ToastActionRole.destructive,
        loadingOnPress: true,
        onPressed: _work,
      ),
    ));
