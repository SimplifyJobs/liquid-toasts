import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:meta/meta.dart';

/// Built-in semantic intent. Drives the default icon and color on the native
/// side. Every default is overridable via [ToastStyleOverride].
enum ToastSemantic { success, error, warning, info, none }

/// Glass rendering intent. The actual decision (native Liquid Glass on iOS 26+
/// vs. a frosted-material fallback below) is made **at render time on-device**;
/// Dart only expresses intent. [adaptive] is the right default everywhere.
enum ToastGlass { adaptive, liquid, frosted, solid, none }

/// Haptic feedback fired when a toast appears. Defaults are derived from the
/// toast's [ToastSemantic] when left unset.
enum ToastHaptic { none, success, warning, error, selection }

/// How a determinate progress value renders.
///
/// - [linear] — a horizontal bar under the text (fills the toast width).
/// - [circular] — a compact determinate ring in the leading slot, in place of
///   the icon (an upload/download-style indicator).
enum ToastProgressStyle { linear, circular }

/// An animated SF Symbol effect applied to the toast's icon.
///
/// - [bounce] fires once when the icon appears.
/// - [pulse], [variableColor] loop while visible (iOS 17+).
/// - [wiggle], [rotate], [breathe] loop while visible (iOS 18+; fall back to
///   [pulse] on iOS 17).
/// - [drawOn] traces the symbol on as it appears (SF Symbols 7 / iOS 26+; falls
///   back to [bounce] below). Best on stroke-based symbols.
enum ToastSymbolEffect {
  none,
  bounce,
  pulse,
  wiggle,
  rotate,
  breathe,
  variableColor,
  drawOn,
}

/// A color that adapts to light/dark appearance without a [BuildContext].
///
/// Pass one [Color] for a frozen (non-adaptive) value, or supply [dark] to get
/// a value that resolves natively against the trait collection — the
/// context-free equivalent of a dynamic system color. Prefer semantic roles
/// (which are fully adaptive) over frozen overrides where possible.
@immutable
class ToastColor {
  const ToastColor(this.light, {Color? dark}) : dark = dark ?? light;

  /// Builds a [ToastColor] from hex strings. Accepts `#RRGGBB`, `#AARRGGBB`,
  /// or the same without the leading `#` / with a `0x` prefix (case-insensitive).
  /// A 6-digit value is treated as fully opaque. Supply [dark] for a distinct
  /// dark-mode value; otherwise [light] is reused.
  ///
  /// ```dart
  /// ToastColor.hex('#b0afb0');
  /// ToastColor.hex('#2196F3', dark: '#0D47A1');
  /// ```
  factory ToastColor.hex(String light, {String? dark}) => ToastColor(
        _parseHex(light),
        dark: dark == null ? null : _parseHex(dark),
      );

  final Color light;
  final Color dark;

  static Color _parseHex(String input) {
    var hex = input.trim();
    if (hex.startsWith('#')) hex = hex.substring(1);
    if (hex.startsWith('0x') || hex.startsWith('0X')) hex = hex.substring(2);
    if (hex.length == 6) hex = 'ff$hex';
    final value = hex.length == 8 ? int.tryParse(hex, radix: 16) : null;
    if (value == null) {
      throw ArgumentError.value(
        input,
        'hex',
        'Expected a hex color like "#RRGGBB" or "#AARRGGBB"',
      );
    }
    return Color(value);
  }

  /// Wire format: `{light: ARGB, dark: ARGB}`.
  Map<String, int> toMap() => {
        'light': light.toARGB32(),
        'dark': dark.toARGB32(),
      };

  @override
  bool operator ==(Object other) =>
      other is ToastColor && other.light == light && other.dark == dark;

  @override
  int get hashCode => Object.hash(light, dark);
}

/// Per-toast visual override. Every field is null-means-inherit: anything left
/// null falls back to the semantic-derived value computed natively (which is
/// where the adaptive Liquid Glass / dark-mode defaults live).
@immutable
class ToastStyleOverride {
  const ToastStyleOverride({
    this.tint,
    this.background,
    this.foreground,
    this.iconColor,
    this.glass,
    this.cornerRadius,
    this.symbolEffect = ToastSymbolEffect.none,
  });

  /// Accent tint. Colors the icon, spinner, and progress ring — never the
  /// surface. Use [background] to color the surface.
  final ToastColor? tint;

  /// Surface color. On iOS 26+ this tints the Liquid Glass (a translucent wash
  /// over the live refraction — pass a reduced alpha for subtlety); on the iOS
  /// 17–25 frosted tier and under Reduce Transparency, and on Android, it fills
  /// the (opaque) surface. Null keeps the neutral adaptive default.
  ///
  /// When set and [foreground] is left null, a readable text color (near-black
  /// or near-white, per light/dark) is chosen automatically by contrast.
  final ToastColor? background;

  /// Title + message color. When null and [background] is set, it is derived
  /// automatically for contrast; otherwise the native default (`.primary`).
  final ToastColor? foreground;

  /// Icon color (defaults to [foreground] or [tint] natively).
  final ToastColor? iconColor;

  /// Glass treatment. Null inherits the app-wide default ([ToastGlass.adaptive]).
  final ToastGlass? glass;

  /// Corner radius. Null lets native choose (capsule for compact, rounded rect
  /// for multi-line).
  final double? cornerRadius;

  /// Animated effect applied to the icon's SF Symbol.
  final ToastSymbolEffect symbolEffect;

  /// [semantic] lets the icon auto-color decision see the toast's intent: a
  /// semantic toast keeps its role-colored glyph even over a custom surface.
  Map<String, Object?> toMap({ToastSemantic? semantic}) {
    final effectiveForeground = foreground ?? _autoForeground();
    final effectiveIconColor = iconColor ?? _autoIconColor(semantic);
    return {
      if (tint != null) 'tint': tint!.toMap(),
      if (background != null) 'background': background!.toMap(),
      if (effectiveForeground != null) 'foreground': effectiveForeground.toMap(),
      if (effectiveIconColor != null) 'iconColor': effectiveIconColor.toMap(),
      if (glass != null) 'glass': glass!.name,
      if (cornerRadius != null) 'cornerRadius': cornerRadius,
      if (symbolEffect != ToastSymbolEffect.none)
        'symbolEffect': symbolEffect.name,
    };
  }

  /// A readable text color derived from [background] for contrast, or null when
  /// there is no (sufficiently opaque) background to derive from.
  ToastColor? _autoForeground() {
    final bg = background;
    if (bg == null || !_isOpaqueEnough(bg)) return null;
    return ToastColor(
      _onColor(bg.light, _lightSurfaceBase),
      dark: _onColor(bg.dark, _darkSurfaceBase),
    );
  }

  /// The icon on-color, only when the icon would otherwise be neutral: no
  /// explicit [iconColor]/[tint] and no semantic role to color it. Keeps the
  /// glyph readable over a custom surface without overriding a semantic color.
  ToastColor? _autoIconColor(ToastSemantic? semantic) {
    if (tint != null) return null; // tint already drives the icon
    if ((semantic ?? ToastSemantic.none) != ToastSemantic.none) return null;
    return _autoForeground();
  }

  // Assumed surface base the tint composites over when computing contrast
  // (mirrors the neutral opaque fills used natively). Near-, not pure-, B/W
  // text keeps the look soft.
  static const Color _lightSurfaceBase = Color(0xFFFAFAFA);
  static const Color _darkSurfaceBase = Color(0xFF242424);
  static const Color _onLightText = Color(0xFF1A1A1A);
  static const Color _onDarkText = Color(0xFFF5F5F5);

  static bool _isOpaqueEnough(ToastColor c) => c.light.a >= 0.5 || c.dark.a >= 0.5;

  /// Picks the near-black or near-white text with the higher WCAG contrast
  /// ratio against [bg] (composited over [base] to account for any alpha).
  static Color _onColor(Color bg, Color base) {
    final l = _relativeLuminance(_composite(bg, base));
    final contrastWhite = 1.05 / (l + 0.05);
    final contrastBlack = (l + 0.05) / 0.05;
    return contrastWhite >= contrastBlack ? _onDarkText : _onLightText;
  }

  static Color _composite(Color fg, Color base) {
    final a = fg.a;
    return Color.from(
      alpha: 1,
      red: fg.r * a + base.r * (1 - a),
      green: fg.g * a + base.g * (1 - a),
      blue: fg.b * a + base.b * (1 - a),
    );
  }

  static double _relativeLuminance(Color c) {
    double lin(double x) =>
        x <= 0.03928 ? x / 12.92 : math.pow((x + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b);
  }
}
