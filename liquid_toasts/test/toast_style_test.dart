import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_toasts/src/toast.dart';
import 'package:liquid_toasts/src/toast_style.dart';

// Derived on-color constants (mirror ToastStyleOverride).
const _nearBlack = 0xFF1A1A1A;
const _nearWhite = 0xFFF5F5F5;

Map<String, Object?>? styleMap(Toast t) =>
    t.toMap()['style'] as Map<String, Object?>?;

int? fgLight(Toast t) =>
    (styleMap(t)?['foreground'] as Map?)?['light'] as int?;
int? iconLight(Toast t) =>
    (styleMap(t)?['iconColor'] as Map?)?['light'] as int?;

void main() {
  group('ToastColor.hex', () {
    test('parses 6-digit as opaque', () {
      expect(ToastColor.hex('#b0afb0').light, const Color(0xFFB0AFB0));
      expect(ToastColor.hex('b0afb0').light, const Color(0xFFB0AFB0));
    });

    test('parses 8-digit with alpha', () {
      expect(ToastColor.hex('#80b0afb0').light, const Color(0x80B0AFB0));
      expect(ToastColor.hex('0xFF2196F3').light, const Color(0xFF2196F3));
    });

    test('distinct dark value', () {
      final c = ToastColor.hex('#2196F3', dark: '#0D47A1');
      expect(c.light, const Color(0xFF2196F3));
      expect(c.dark, const Color(0xFF0D47A1));
    });

    test('invalid input throws ArgumentError', () {
      expect(() => ToastColor.hex('nope'), throwsArgumentError);
      expect(() => ToastColor.hex('#12345'), throwsArgumentError);
    });
  });

  group('background serialization', () {
    test('emits background as {light,dark}', () {
      final t = Toast(
        message: 'hi',
        style: const ToastStyleOverride(background: ToastColor(Color(0xFFB0AFB0))),
      );
      final bg = styleMap(t)?['background'] as Map?;
      expect(bg?['light'], 0xFFB0AFB0);
      expect(bg?['dark'], 0xFFB0AFB0);
    });
  });

  group('auto foreground', () {
    test('light background -> near-black text', () {
      final t = Toast(
        message: 'hi',
        style: const ToastStyleOverride(background: ToastColor(Color(0xFFF0F0F0))),
      );
      expect(fgLight(t), _nearBlack);
    });

    test('dark background -> near-white text', () {
      final t = Toast(
        message: 'hi',
        style: const ToastStyleOverride(background: ToastColor(Color(0xFF101010))),
      );
      expect(fgLight(t), _nearWhite);
    });

    test('#b0afb0 (light-ish grey) -> near-black text', () {
      final t = Toast(
        message: 'hi',
        style: const ToastStyleOverride(background: ToastColor(Color(0xFFB0AFB0))),
      );
      expect(fgLight(t), _nearBlack);
    });

    test('per-scheme: light/dark backgrounds derive independently', () {
      final t = Toast(
        message: 'hi',
        style: const ToastStyleOverride(
          background: ToastColor(Color(0xFFF0F0F0), dark: Color(0xFF101010)),
        ),
      );
      final fg = styleMap(t)?['foreground'] as Map?;
      expect(fg?['light'], _nearBlack);
      expect(fg?['dark'], _nearWhite);
    });

    test('explicit foreground always wins', () {
      final t = Toast(
        message: 'hi',
        style: const ToastStyleOverride(
          background: ToastColor(Color(0xFF101010)),
          foreground: ToastColor(Color(0xFF00FF00)),
        ),
      );
      expect(fgLight(t), 0xFF00FF00);
    });

    test('no background -> no auto foreground', () {
      final t = Toast(
        message: 'hi',
        style: const ToastStyleOverride(tint: ToastColor(Color(0xFF2196F3))),
      );
      expect(fgLight(t), isNull);
    });

    test('translucent background (alpha < 0.5) -> no auto foreground', () {
      final t = Toast(
        message: 'hi',
        style: const ToastStyleOverride(background: ToastColor(Color(0x40101010))),
      );
      expect(fgLight(t), isNull);
    });
  });

  group('auto icon color', () {
    test('semantic none + no tint -> icon uses on-color', () {
      final t = Toast(
        message: 'hi',
        style: const ToastStyleOverride(background: ToastColor(Color(0xFF101010))),
      );
      expect(iconLight(t), _nearWhite);
    });

    test('semantic toast keeps its role-colored icon (no auto icon color)', () {
      final t = Toast.success(
        message: 'saved',
        style: const ToastStyleOverride(background: ToastColor(Color(0xFF101010))),
      );
      expect(iconLight(t), isNull);
    });

    test('explicit tint suppresses auto icon color', () {
      final t = Toast(
        message: 'hi',
        style: const ToastStyleOverride(
          background: ToastColor(Color(0xFF101010)),
          tint: ToastColor(Color(0xFF2196F3)),
        ),
      );
      expect(iconLight(t), isNull);
    });
  });
}
