import SwiftUI
import UIKit

/// The toast's leading glyph: a rotating spinner while loading, otherwise a
/// validated SF Symbol that animates its swap and (optionally) an ongoing
/// SF Symbol effect.
struct IconView: View {
  let toast: ToastModel
  @Environment(\.colorScheme) private var scheme
  @State private var appeared = false

  private var tintColor: Color {
    if let c = toast.style?.iconColor?.resolved(scheme) { return c }
    if let c = toast.style?.tint?.resolved(scheme) { return c }
    return toast.semantic.tint
  }

  private var effect: ToastSymbolEffect { toast.style?.symbolEffect ?? .none }

  var body: some View {
    ZStack {
      if toast.state == .loading {
        SpinnerView(color: tintColor)
          .transition(.scale.combined(with: .opacity))
      } else if let symbol = validatedSymbol {
        symbolImage(symbol)
          .transition(.scale.combined(with: .opacity))
      }
    }
    .frame(width: ToastMetrics.iconSlot, height: ToastMetrics.iconSlot)
    .animation(ToastMetrics.settleSpring, value: toast.state)
  }

  @ViewBuilder
  private func symbolImage(_ symbol: String) -> some View {
    let base = Image(systemName: symbol)
      .font(.system(size: 17, weight: .semibold))
      .symbolRenderingMode(.hierarchical)
      .foregroundStyle(tintColor)
      .contentTransition(.symbolEffect(.replace.downUp))
    applyEffect(base)
      .onAppear { appeared = true }
  }

  /// Applies the requested SF Symbol effect. `bounce` fires once when the icon
  /// appears; the others loop while visible. `wiggle`/`rotate`/`breathe` need
  /// iOS 18 and fall back to `pulse` on iOS 17.
  @ViewBuilder
  private func applyEffect(_ view: some View) -> some View {
    switch effect {
    case .none:
      view
    case .bounce:
      view.symbolEffect(.bounce, value: appeared)
    case .pulse:
      view.symbolEffect(.pulse, isActive: true)
    case .variableColor:
      view.symbolEffect(.variableColor.iterative.reversing, isActive: true)
    case .wiggle:
      if #available(iOS 18.0, *) {
        view.symbolEffect(.wiggle, isActive: true)
      } else {
        view.symbolEffect(.pulse, isActive: true)
      }
    case .rotate:
      if #available(iOS 18.0, *) {
        view.symbolEffect(.rotate, isActive: true)
      } else {
        view.symbolEffect(.pulse, isActive: true)
      }
    case .breathe:
      if #available(iOS 18.0, *) {
        view.symbolEffect(.breathe, isActive: true)
      } else {
        view.symbolEffect(.pulse, isActive: true)
      }
    case .drawOn:
      // `.drawOn`'s isActive is inverted: true = hidden (pre-draw). Starting
      // hidden then flipping on appear traces the symbol on.
      #if compiler(>=6.2)
      if #available(iOS 26.0, *) {
        view.symbolEffect(.drawOn, isActive: !appeared)
      } else {
        view.symbolEffect(.bounce, value: appeared)
      }
      #else
      view.symbolEffect(.bounce, value: appeared)
      #endif
    }
  }

  /// `Image(systemName:)` silently renders nothing for an unknown name, so we
  /// validate with `UIImage(systemName:)` first and fall back to the semantic
  /// default if the caller's symbol is invalid on this OS version.
  private var validatedSymbol: String? {
    guard let name = toast.resolvedSymbol else { return nil }
    if UIImage(systemName: name) != nil { return name }
    if let fallback = toast.semantic.defaultSymbol, UIImage(systemName: fallback) != nil {
      return fallback
    }
    return nil
  }
}

/// A lightweight indeterminate spinner — a trimmed circle stroke spinning
/// forever, sized to match the icon slot.
struct SpinnerView: View {
  let color: Color
  @State private var rotation: Double = 0

  var body: some View {
    Circle()
      .trim(from: 0, to: 0.72)
      .stroke(color.opacity(0.85), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
      .frame(width: 17, height: 17)
      .rotationEffect(.degrees(rotation))
      .onAppear {
        withAnimation(.linear(duration: 0.85).repeatForever(autoreverses: false)) {
          rotation = 360
        }
      }
  }
}
