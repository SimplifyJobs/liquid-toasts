import 'dart:typed_data' show Uint8List;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:liquid_toasts/liquid_toasts.dart';

import 'demo_harness.dart';

/// The kitchen-sink reel: one preview per toast variation the package
/// supports, exercised through the new `toast` API. Used to eyeball the whole
/// surface after a refactor and to record the review video for PRs.
///
/// Record it:  tool/record_demo.sh --target lib/full_showcase_demo.dart --prefix FULL --contact
/// Run it:     cd example && flutter run -t lib/full_showcase_demo.dart   (iOS 26+ sim)
void main() {
  runDemoReel(
    prefix: 'FULL',
    previews: {
      'semantics': _semantics,
      'titled-wrap': _titledWrap,
      'centered-compact': _centeredCompact,
      'multiline-morph': _multilineMorph,
      'avatar': _avatar,
      'progress-circular': _progressCircular,
      'progress-linear': _progressLinear,
      'action-undo': _actionUndo,
      'action-async': _actionAsync,
      'promise-success': _promiseSuccess,
      'promise-error': _promiseError,
      'positions': _positions,
      'groupkey-replace': _groupKeyReplace,
      'shake-in-place': _shakeInPlace,
      'stacking': _stacking,
    },
  );
}

const _hold = Duration(milliseconds: 1500);

Future<void> _wait(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

// 1. The five semantic one-liners, staggered into a stack.
Future<void> _semantics() async {
  toast('Plain message');
  await _wait(700);
  toast.success('Saved to favorites');
  await _wait(700);
  toast.error('Could not connect');
  await _wait(700);
  toast.warning('Low storage');
  await _wait(700);
  toast.info('3 updates available');
  await _wait(4200);
}

// 2. Bold title that wraps to two lines above a wrapping message.
Future<void> _titledWrap() async {
  toast.show(
    'Long titles can wrap onto a second line instead of truncating, and the '
    'message reflows underneath.',
    title: 'A headline long enough to need a second line',
    icon: 'text.alignleft',
    titleMaxLines: 2,
    maxLines: 3,
    duration: const Duration(milliseconds: 4200),
  );
  await _wait(4200 + 1500);
}

// 3. A compact text-only toast centers its text (no icon, no action).
Future<void> _centeredCompact() async {
  toast.show('Copied', icon: null, duration: const Duration(milliseconds: 2600));
  await _wait(3200);
  toast.show(
    'Link copied to clipboard',
    duration: const Duration(milliseconds: 2600),
  );
  await _wait(2600 + 1500);
}

// 4. Patch updates morph a hugging capsule across the multiline boundary.
Future<void> _multilineMorph() async {
  final t = toast.loading('Preparing export…');
  await _wait(1900);
  t.update(
    loading: false,
    semantic: ToastSemantic.success,
    message: 'Your export is ready — 42 photos and 3 videos were bundled '
        'into a single archive.',
    maxLines: 3,
    duration: const Duration(milliseconds: 3800),
  );
  await _wait(3800 + 1500);
}

// 5. Leading avatar image in place of the SF Symbol.
Future<void> _avatar() async {
  final bytes = await _avatarPng('AR', const [Color(0xFF7C3AED), Color(0xFF4F46E5)]);
  toast.show(
    'Alex Rivera sent you a message',
    leadingImage: MemoryImage(bytes),
    duration: const Duration(milliseconds: 3600),
    onTap: () {},
  );
  await _wait(3600 + 1500);
}

// 6. Determinate circular ring in the leading slot, driven by patches.
Future<void> _progressCircular() async {
  final t = toast.show(
    'Uploading video…',
    duration: null,
    progress: 0,
    progressStyle: ToastProgressStyle.circular,
  );
  for (var p = 0.0; p <= 1.0; p += 0.1) {
    t.update(progress: p);
    await _wait(240);
  }
  t.update(
    message: 'Upload complete',
    semantic: ToastSemantic.success,
    progress: 1.0,
    duration: const Duration(milliseconds: 2400),
  );
  await _wait(2400 + 1500);
}

// 7. Full-width linear bar under a wrapping message.
Future<void> _progressLinear() async {
  final t = toast.show(
    'Downloading "Interstellar" for offline viewing on your commute.',
    icon: 'arrow.down.circle',
    duration: null,
    progress: 0,
    maxLines: 2,
  );
  for (var p = 0.0; p <= 1.0; p += 0.08) {
    t.update(progress: p);
    await _wait(200);
  }
  t.update(
    message: 'Download complete',
    semantic: ToastSemantic.success,
    progress: 1.0,
    duration: const Duration(milliseconds: 2400),
  );
  await _wait(2400 + 1500);
}

// 8. A sync action button (Undo) on a persistent toast.
Future<void> _actionUndo() async {
  final t = toast.show(
    'Conversation archived',
    icon: 'archivebox.fill',
    duration: null,
    action: ToastAction(label: 'Undo', onPressed: () {}),
  );
  await _wait(3800);
  await t.dismiss();
  await _wait(_hold.inMilliseconds);
}

// 9. Async actions: spinner-until-resolve, with and without auto-dismiss.
Future<void> _actionAsync() async {
  final approve = toast.show(
    'Approve Alex’s time-off request?',
    icon: 'calendar.badge.clock',
    duration: null,
    action: ToastAction(
      label: 'Approve',
      loadingOnPress: true,
      onPressed: () => _wait(1700), // dismissOnPress: true (default)
    ),
  );
  await _wait(1100);
  // No real touch in an automated reel — fire the button as a tap would.
  // ignore: invalid_use_of_visible_for_testing_member
  await toast.debugTriggerAction(approve.id);
  await approve.onDismissed;
  await _wait(900);

  final retry = toast.show(
    'Sync failed — 3 items pending',
    semantic: ToastSemantic.warning,
    duration: null,
    action: ToastAction(
      label: 'Retry',
      loadingOnPress: true,
      dismissOnPress: false, // spinner clears, toast stays
      onPressed: () => _wait(1700),
    ),
  );
  await _wait(1100);
  // ignore: invalid_use_of_visible_for_testing_member
  await toast.debugTriggerAction(retry.id);
  await _wait(2600);
  await retry.dismiss();
  await _wait(_hold.inMilliseconds);
}

// 10. toast.promise — spinner morphs to the success phase, value returned.
Future<void> _promiseSuccess() async {
  await toast.promise<String>(
    _wait(2200).then((_) => 'ok'),
    loading: 'Signing in…',
    success: (v) => 'Welcome back, Alex!',
  );
  await _wait(3000 + 1500);
}

// 11. toast.promise — error phase, error rethrown to the caller.
Future<void> _promiseError() async {
  try {
    await toast.promise<void>(
      _wait(2200).then((_) => throw StateError('boom')),
      loading: 'Uploading…',
      error: 'Upload failed — check your connection',
    );
  } catch (_) {/* the reel owns the outcome */}
  await _wait(4000 + 1500);
}

// 12. Independent per-position stacks: bottom and top at once.
Future<void> _positions() async {
  toast.show('Copied link', icon: 'link', position: ToastPosition.bottomCenter,
      duration: const Duration(milliseconds: 4000));
  await _wait(800);
  toast.success('Saved', duration: const Duration(milliseconds: 4000));
  await _wait(4000 + 1500);
}

// 13. Replace-by-groupKey morphs in place instead of stacking duplicates.
Future<void> _groupKeyReplace() async {
  toast.info('Reconnecting…', groupKey: 'net', duration: null);
  await _wait(1400);
  toast.info('Reconnecting (2)…', groupKey: 'net', duration: null);
  await _wait(1400);
  toast.success('Connected', groupKey: 'net',
      duration: const Duration(milliseconds: 2600));
  await _wait(2600 + 1500);
}

// 14. Re-showing a same-group toast whose text is unchanged shakes it in place
// instead of replaying exit+enter (contrast with #13, where the text changes
// and it morphs/replaces).
Future<void> _shakeInPlace() async {
  for (var i = 0; i < 4; i++) {
    toast.success(
      'Link copied',
      groupKey: 'copy',
      duration: const Duration(seconds: 6),
    );
    await _wait(850);
  }
  await _wait(_hold.inMilliseconds);
}

// 15. Rapid stacking — newest pushes the rest along.
Future<void> _stacking() async {
  for (var i = 1; i <= 4; i++) {
    toast.info('Notification #$i', duration: null);
    await _wait(650);
  }
  await _wait(2200);
  await toast.dismissAll();
  await _wait(_hold.inMilliseconds);
}

/// Draws a square gradient tile with centered initials and returns PNG bytes
/// (the native side clips it to a circle).
Future<Uint8List> _avatarPng(String initials, List<Color> colors) async {
  const size = 120.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  const rect = Rect.fromLTWH(0, 0, size, size);
  canvas.drawRect(
    rect,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors,
      ).createShader(rect),
  );
  final tp = TextPainter(
    text: TextSpan(
      text: initials,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 52,
        fontWeight: FontWeight.w600,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, Offset((size - tp.width) / 2, (size - tp.height) / 2));
  final image = await recorder.endRecording().toImage(size.toInt(), size.toInt());
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}
