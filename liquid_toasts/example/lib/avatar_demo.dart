import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:liquid_toasts/liquid_toasts.dart';

import 'demo_harness.dart';

/// Demo reel for the leading image / avatar feature.
///
/// `Toast.leadingImage` takes any Flutter `ImageProvider`. Here the avatars are
/// *drawn in Flutter* (a gradient + initials via `Canvas`/`TextPainter`) and
/// passed as a `MemoryImage` — the package resolves it to bytes off the Flutter
/// image pipeline and hands it to the native renderer as a circular avatar.
/// `AssetImage` / `NetworkImage` work identically.
///
/// Record:  tool/record_demo.sh --target lib/avatar_demo.dart --prefix AVATAR
void main() {
  runDemoReel(
    prefix: 'AVATAR',
    previews: {
      'message': _message,
      'mention': _mention,
      'photos': _photos,
    },
  );
}

const _hold = Duration(milliseconds: 1600);

/// Draws a square gradient tile with centered initials and returns PNG bytes.
/// The native side clips it to a circle, so the square fills the avatar.
Future<Uint8List> _avatar(String initials, List<Color> colors) async {
  const size = 120.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final rect = const Rect.fromLTWH(0, 0, size, size);
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

Future<void> _message() async {
  final bytes = await _avatar('AR', const [Color(0xFF7C3AED), Color(0xFF4F46E5)]);
  toast.raw(Toast(
    message: 'Alex Rivera sent you a message',
    leadingImage: MemoryImage(bytes),
    duration: const Duration(milliseconds: 3600),
  ));
  await Future<void>.delayed(const Duration(milliseconds: 3600) + _hold);
}

Future<void> _mention() async {
  final bytes = await _avatar('SC', const [Color(0xFFEA580C), Color(0xFFDB2777)]);
  toast.raw(Toast(
    title: 'Sam Chen',
    message: 'mentioned you in #design-review',
    leadingImage: MemoryImage(bytes),
    duration: const Duration(milliseconds: 3600),
  ));
  await Future<void>.delayed(const Duration(milliseconds: 3600) + _hold);
}

Future<void> _photos() async {
  final bytes = await _avatar('M', const [Color(0xFF0F766E), Color(0xFF0EA5E9)]);
  toast.raw(Toast(
    message: 'Maya shared 3 photos with you',
    leadingImage: MemoryImage(bytes),
    duration: const Duration(milliseconds: 3600),
  ));
  await Future<void>.delayed(const Duration(milliseconds: 3600) + _hold);
}
