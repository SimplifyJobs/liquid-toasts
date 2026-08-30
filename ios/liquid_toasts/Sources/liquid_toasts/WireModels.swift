import Flutter
import SwiftUI

/// Wire decoding for the toast models: the `[String: Any]` method-channel
/// payloads Dart sends, turned into the Flutter-free models in `Models.swift`
/// via their plain initializers.
///
/// This file is **bridge** code (it may import Flutter); the models themselves
/// know nothing about the wire format. Keys and defaults must stay in lockstep
/// with `lib/src/toast.dart` — see the wire-protocol invariants in CLAUDE.md.

// MARK: - Color

extension Color {
  /// Builds a color from a 32-bit ARGB int (`0xAARRGGBB`), matching Flutter's
  /// `Color.toARGB32()`.
  init(argb: Int) {
    let a = Double((argb >> 24) & 0xFF) / 255.0
    let r = Double((argb >> 16) & 0xFF) / 255.0
    let g = Double((argb >> 8) & 0xFF) / 255.0
    let b = Double(argb & 0xFF) / 255.0
    self = Color(.sRGB, red: r, green: g, blue: b, opacity: a)
  }
}

extension ToastColor {
  /// Decodes a `{light, dark}` pair of ARGB ints; nil unless both are present.
  init?(wire value: Any?) {
    guard let map = value as? [String: Any],
          let l = map.int("light"),
          let d = map.int("dark") else { return nil }
    self.init(light: Color(argb: l), dark: Color(argb: d))
  }
}

// MARK: - Style / Action models

extension ToastStyleModel {
  init?(wire value: Any?) {
    guard let map = value as? [String: Any] else { return nil }
    self.init(
      tint: ToastColor(wire: map["tint"]),
      background: ToastColor(wire: map["background"]),
      foreground: ToastColor(wire: map["foreground"]),
      iconColor: ToastColor(wire: map["iconColor"]),
      glass: map.enumValue("glass"),
      cornerRadius: map.cgFloat("cornerRadius"),
      symbolEffect: map.enumValue("symbolEffect", default: .none)
    )
  }
}

extension ToastActionModel {
  init?(wire value: Any?) {
    guard let map = value as? [String: Any],
          let actionId = map["actionId"] as? String,
          let label = map["label"] as? String else { return nil }
    self.init(
      actionId: actionId,
      label: label,
      role: map.enumValue("role", default: .primary),
      color: ToastColor(wire: map["color"]),
      dismissOnPress: map.bool("dismissOnPress", default: true),
      loadingOnPress: map.bool("loadingOnPress", default: false)
    )
  }
}

// MARK: - Toast model

extension ToastModel {
  /// Decodes a `show`/`update` payload. Fails (nil) when `id` or `message` is
  /// missing — the plugin turns that into an `INVALID_ARGS` channel error.
  init?(arguments: Any?) {
    guard let map = arguments as? [String: Any],
          let id = map["id"] as? String,
          let message = map["message"] as? String else { return nil }
    self.init(
      id: id,
      message: message,
      title: map["title"] as? String,
      icon: map["icon"] as? String,
      // Image bytes are NOT decoded here: the plugin unwraps them to `Data` and
      // hands them to the manager, which decodes off the main thread and
      // attaches the pixels when ready (see ToastImageDecoder). This flag only
      // reserves the avatar slot in the meantime.
      expectsImage: map["image"] is FlutterStandardTypedData,
      semantic: map.enumValue("semantic", default: .none),
      style: ToastStyleModel(wire: map["style"]),
      position: map.enumValue("position", default: .topCenter),
      state: map.enumValue("state", default: .static),
      persistent: map.bool("persistent", default: false),
      durationMs: map.int("durationMs"),
      useDynamicIslandOrigin: map.bool("useDynamicIslandOrigin", default: true),
      progress: map.double("progress"),
      progressStyle: map.enumValue("progressStyle", default: .linear),
      groupKey: map["groupKey"] as? String,
      haptic: map.enumValue("haptic", default: .none),
      semanticsLabel: map["semanticsLabel"] as? String,
      maxLines: map.int("maxLines") ?? 1,
      titleMaxLines: map.int("titleMaxLines") ?? 1,
      tapToDismiss: map.bool("tapToDismiss", default: true),
      hasTap: map.bool("hasTap", default: false),
      action: ToastActionModel(wire: map["action"])
    )
  }
}
