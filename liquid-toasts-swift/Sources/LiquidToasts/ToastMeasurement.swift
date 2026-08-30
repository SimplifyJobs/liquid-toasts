import SwiftUI
import UIKit

/// Everything the two off-screen measurement probes depend on. Equatable so
/// the probes re-lay-out only when a measurement-relevant input changes — a
/// progress tick, spinner flip, or drag no longer re-runs two hidden Text
/// layouts per toast.
struct ToastMeasurementInputs: Equatable {
  var message: String
  var title: String?
  var maxLines: Int
  var hasAction: Bool
  var showsLeading: Bool
  /// Fed back from the live ActionButton's measured width.
  var actionWidth: CGFloat
  var multilineWidth: CGFloat
}

/// The two hidden off-screen probes, rendered in `ToastView`'s background:
///
/// - the **multiline probe** measures the message at the width it would occupy
///   in the multiline layout — if it needs more than one line there, the toast
///   commits to the multiline treatment. Measuring at a *fixed* reference
///   width (not the live layout width) keeps the decision stable: it can't
///   feed back into itself and oscillate as the layout flips between capsule
///   and rounded rect.
/// - the **width probe** measures the row at its single-line (hugging) width —
///   the concrete width single-line mode frames to, so the toast can animate
///   between it and the multiline width rather than snapping.
///
/// Both only *emit* preferences ([MessageHeightKey], [NaturalWidthKey]);
/// `ToastView` owns the handlers and the state they drive. Every inset here
/// routes through [ToastMetrics], structurally in lockstep with the live
/// layout.
struct ToastMeasurementProbes: View, Equatable {
  let inputs: ToastMeasurementInputs

  static func == (lhs: Self, rhs: Self) -> Bool { lhs.inputs == rhs.inputs }

  var body: some View {
    ZStack {
      multilineProbe
      widthProbe
    }
  }

  private var multilineProbe: some View {
    // Multiline hypothesis: the message wraps, so the row is always tall.
    let leading = ToastMetrics.leadingPadding(multiline: true, hasLeadingSlot: inputs.showsLeading, tallRow: true)
    let trailing = ToastMetrics.trailingPadding(multiline: true, hasAction: inputs.hasAction)
    let spacing = ToastMetrics.rowSpacing(multiline: true)
    let glyph: CGFloat = inputs.showsLeading ? ToastMetrics.iconSlot + spacing : 0
    // Subtract the action button (measured; estimate until first layout) + spacing.
    let act: CGFloat = inputs.hasAction
      ? (inputs.actionWidth > 0 ? inputs.actionWidth : ToastMetrics.actionWidthEstimate) + spacing
      : 0
    let reference = max(
      ToastMetrics.probeMinReferenceWidth,
      inputs.multilineWidth - leading - trailing - glyph - act)
    return Text(inputs.message)
      .font(.system(.subheadline, design: .rounded))
      .lineLimit(inputs.maxLines)
      .fixedSize(horizontal: false, vertical: true)
      .frame(width: reference, alignment: .leading)
      .background(
        GeometryReader { geo in
          Color.clear.preference(key: MessageHeightKey.self, value: geo.size.height)
        }
      )
      .hidden()
  }

  private var widthProbe: some View {
    HStack(spacing: ToastMetrics.rowSpacing(multiline: false)) {
      if inputs.showsLeading {
        Color.clear.frame(width: ToastMetrics.iconSlot, height: ToastMetrics.iconSlot)
      }
      VStack(alignment: .leading, spacing: 2) {
        if let title = inputs.title, !title.isEmpty {
          Text(title)
            .font(.system(.subheadline, design: .rounded).weight(.semibold))
            .lineLimit(1)
        }
        Text(inputs.message)
          .font(.system(.subheadline, design: .rounded))
          .lineLimit(1)
      }
      .frame(maxWidth: ToastMetrics.textColumnMaxWidth, alignment: .leading)
      if inputs.hasAction {
        Color.clear.frame(width: max(1, inputs.actionWidth), height: 1)
      }
    }
    .padding(.leading,
             ToastMetrics.leadingPadding(
               multiline: false,
               hasLeadingSlot: inputs.showsLeading,
               // Single-line hypothesis: tall when an action button or a title
               // above the message adds a second line.
               tallRow: inputs.hasAction
                 || (inputs.title?.isEmpty == false && !inputs.message.isEmpty)))
    .padding(.trailing,
             ToastMetrics.trailingPadding(multiline: false, hasAction: inputs.hasAction))
    .fixedSize(horizontal: true, vertical: false)
    .background(
      GeometryReader { geo in
        Color.clear.preference(key: NaturalWidthKey.self, value: geo.size.width)
      }
    )
    .hidden()
  }
}

// MARK: - Preference keys

/// Carries the rendered height of the off-screen message probe up to `ToastView`
/// so it can decide whether the message wraps past a single line.
struct MessageHeightKey: PreferenceKey {
  static var defaultValue: CGFloat = 0
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = max(value, nextValue())
  }
}

/// Carries the action button's rendered width up to `ToastView` so the multiline
/// probe can subtract the horizontal space the button occupies.
struct ActionWidthKey: PreferenceKey {
  static var defaultValue: CGFloat = 0
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = max(value, nextValue())
  }
}

/// Carries the single-line (hugging) row width up to `ToastView` so single-line
/// mode frames to a concrete width and can animate across the multiline boundary.
struct NaturalWidthKey: PreferenceKey {
  static var defaultValue: CGFloat = 0
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = max(value, nextValue())
  }
}
