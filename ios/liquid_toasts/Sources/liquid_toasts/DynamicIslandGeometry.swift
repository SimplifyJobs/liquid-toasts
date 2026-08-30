import UIKit

/// Public-API-only cutout detection. Deliberately avoids the private
/// `_exclusionArea` selector (an App Store rejection + crash risk); instead it
/// classifies by safe-area insets + a centered pill approximation, which is
/// enough to anchor the Dynamic Island origin animation.
@MainActor
public enum DynamicIslandGeometry {
  static func safeTop(_ window: UIWindow?) -> CGFloat { window?.safeAreaInsets.top ?? 0 }

  static func isPortrait(_ window: UIWindow?) -> Bool {
    guard let orientation = window?.windowScene?.interfaceOrientation else { return true }
    return orientation.isPortrait
  }

  /// `"dynamicIsland"`, `"notch"`, or `"none"` from the top safe-area inset.
  static func cutoutType(_ window: UIWindow?) -> String {
    let top = safeTop(window)
    if top >= 51 { return "dynamicIsland" } // DI devices report ~59pt
    if top >= 30 { return "notch" }         // notch devices ~44–50pt
    return "none"
  }

  /// True only when a Dynamic Island is present and the device is in portrait
  /// (the island-origin animation is portrait-only).
  static func hasDynamicIsland(_ window: UIWindow?) -> Bool {
    cutoutType(window) == "dynamicIsland" && isPortrait(window)
  }

  /// Approximate Dynamic Island pill frame (centered) in window coordinates.
  static func islandFrame(_ window: UIWindow?) -> CGRect {
    let width = window?.bounds.width ?? UIScreen.main.bounds.width
    let pillWidth: CGFloat = 126
    let pillHeight: CGFloat = 37
    let topInset: CGFloat = 11
    return CGRect(x: (width - pillWidth) / 2, y: topInset, width: pillWidth, height: pillHeight)
  }

  /// Advisory device-geometry + capability snapshot (safe area, screen, cutout,
  /// glass mode). Wire-shaped: this is exactly what the Dart `queryGeometry`
  /// call returns. Pass `ToastOverlayHost.activeWindow()`.
  public static func geometrySnapshot(_ window: UIWindow?) -> [String: Any] {
    let insets = window?.safeAreaInsets ?? .zero
    let bounds = window?.bounds ?? UIScreen.main.bounds
    let type = cutoutType(window)

    var dict: [String: Any] = [
      "hasDynamicIsland": type == "dynamicIsland",
      "cutoutType": type,
      "safeArea": [
        "top": insets.top, "left": insets.left,
        "right": insets.right, "bottom": insets.bottom,
      ],
      "screen": [
        "width": bounds.width, "height": bounds.height,
        "scale": window?.screen.scale ?? UIScreen.main.scale,
      ],
      "supportsDynamicIslandOrigin": hasDynamicIsland(window),
      "glassMode": Capabilities.glassModeString,
      "iosVersion": UIDevice.current.systemVersion,
    ]
    if type != "none" {
      let frame = islandFrame(window)
      dict["exclusionRect"] = [
        "x": frame.minX, "y": frame.minY,
        "width": frame.width, "height": frame.height,
      ]
    }
    return dict
  }
}
