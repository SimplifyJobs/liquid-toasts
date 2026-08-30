import SwiftUI
import UIKit

/// Adaptive glass surface for a toast.
///
/// - iOS 27+: native Liquid Glass via `glassEffect`. The neutral (no caller
///   color) surface is left as bare `.regular`, so it follows the user's
///   system-wide Liquid Glass translucency slider (Settings ▸ Appearance). A
///   caller-supplied `surfaceTint` (`ToastStyleOverride.background`) is still
///   capped to [maxGlassTintAlpha] — an opaque `.tint` renders *heavy* (a flat
///   opaque fill) even on iOS 27, so the cap keeps colored glass translucent.
/// - iOS 26: same `glassEffect` and the same caller-tint cap, but there is no
///   system control, so the neutral surface gets a subtle 0.28 dark/light
///   legibility wash instead of bare `.regular`.
/// - iOS 17–25: a frosted `.ultraThinMaterial` fallback, tinted by
///   `surfaceTint` when set (else a neutral scheme wash).
/// - Reduce Transparency: an opaque background — filled with `surfaceTint` when
///   set, else neutral.
struct GlassBackground<S: Shape>: View {
  let shape: S
  /// Surface color from `ToastStyleOverride.background`. Nil keeps the neutral
  /// adaptive default on every tier.
  var surfaceTint: Color? = nil

  /// Ceiling on the tint alpha for the translucent (glass / frosted) tiers.
  /// Above this, `glassEffect(.tint:)` flips the material to its heavy, opaque
  /// weight and the surface stops reading as glass. The opaque Reduce
  /// Transparency tier is exempt (it *should* be solid).
  static var maxGlassTintAlpha: CGFloat { 0.5 }

  @Environment(\.colorScheme) private var scheme
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

  /// Clamps a surface tint's alpha to [maxGlassTintAlpha] (leaving already-
  /// translucent tints untouched) so colored glass stays translucent.
  private func translucentTint(_ color: Color) -> Color {
    let alpha = UIColor(color).cgColor.alpha
    guard alpha > Self.maxGlassTintAlpha else { return color }
    return color.opacity(Self.maxGlassTintAlpha / alpha)
  }

  var body: some View {
    let isDark = scheme == .dark
    if reduceTransparency {
      shape
        .fill(surfaceTint ?? (isDark ? Color(white: 0.14) : Color(white: 0.98)))
        .overlay(shape.stroke(Color.primary.opacity(0.08), lineWidth: 0.5))
        .shadow(color: .black.opacity(isDark ? 0.4 : 0.14), radius: 14, y: 6)
    } else {
      glass(isDark: isDark)
    }
  }

  @ViewBuilder
  private func glass(isDark: Bool) -> some View {
    #if compiler(>=6.2)
    if #available(iOS 26.0, *) {
      shape
        .fill(.clear)
        .glassEffect(resolvedGlass(isDark: isDark), in: shape)
        // Explicit shadow: the entrance animates opacity/scale/offset on top of
        // this glass, which forces SwiftUI to rasterize it and suppresses the
        // glass's *system* ambient shadow mid-animation (it dips out, then snaps
        // back on settle). Our own shadow is a normal primitive that fades and
        // scales smoothly with the entrance, so the visible shadow stays
        // continuous instead of flickering.
        .shadow(color: .black.opacity(isDark ? 0.24 : 0.08), radius: 10, y: 4)
    } else {
      frosted(isDark: isDark)
    }
    #else
    frosted(isDark: isDark)
    #endif
  }

  /// The `Glass` style for the toast surface.
  ///
  /// A caller `background` is always capped ([translucentTint]) so an opaque
  /// color reads as glass rather than a flat fill — verified still necessary on
  /// iOS 27 at the default slider (an opaque `.tint` still renders heavy). The
  /// *neutral* (no caller color) surface is where the OSes diverge:
  ///   • iOS 27 leaves `.regular` fully system-driven, so it follows the user's
  ///     Liquid Glass translucency slider (Settings ▸ Appearance).
  ///   • iOS 26 has no such control, so a subtle 0.28 dark/light legibility wash
  ///     keeps a neutral toast readable over busy content.
  #if compiler(>=6.2)
  @available(iOS 26.0, *)
  private func resolvedGlass(isDark: Bool) -> Glass {
    if let tint = surfaceTint.map(translucentTint) {
      return .regular.tint(tint)
    }
    if #available(iOS 27.0, *) {
      return .regular
    }
    return .regular.tint((isDark ? Color.black : Color.white).opacity(0.28))
  }
  #endif

  @ViewBuilder
  private func frosted(isDark: Bool) -> some View {
    let wash = surfaceTint.map(translucentTint) ?? (isDark ? Color.black : Color.white).opacity(isDark ? 0.26 : 0.16)
    shape
      .fill(.ultraThinMaterial)
      .overlay(shape.fill(wash))
      .overlay(shape.stroke(Color.white.opacity(isDark ? 0.10 : 0.30), lineWidth: 0.5))
      .shadow(color: .black.opacity(isDark ? 0.35 : 0.12), radius: 16, y: 8)
  }
}
