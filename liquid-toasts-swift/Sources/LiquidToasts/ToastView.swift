import SwiftUI
import UIKit

/// A single toast: orchestrates the row content ([ToastContentView]) on an
/// adaptive glass surface, owning the interaction gestures and the
/// measurement-driven width/wrap state fed by [ToastMeasurementProbes].
struct ToastView: View {
  let toast: ToastModel
  /// Width of the overlay host (device width); drives the multiline width.
  let deviceWidth: CGFloat
  let onTapBody: () -> Void
  let onAction: () -> Void
  let onSwipe: () -> Void
  /// Touch-down / touch-up — used to pause & resume the auto-dismiss timer while
  /// the user is interacting with (reading / holding / dragging) the toast.
  let onPressStart: () -> Void
  let onPressEnd: () -> Void

  @Environment(\.colorScheme) private var scheme
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  /// Drives the one-shot horizontal shake fired when a group toast is re-shown
  /// with unchanged text — tracks [ToastModel.shakeToken].
  @State private var shakeProgress: CGFloat = 0
  @State private var dragOffset: CGFloat = 0
  @State private var isDragging = false
  @State private var isPressed = false
  /// Measured width of the action button, fed back into the multiline probe so
  /// the wrap decision accounts for the space the button takes.
  @State private var actionWidth: CGFloat = 0
  /// True when the message wraps onto more than one line — measured off-screen.
  /// Multiline toasts trade the hugging capsule for a wider, left-aligned
  /// rounded rectangle.
  @State private var isMultiline = false
  /// Hugging (single-line) width, measured off-screen. Used as the concrete
  /// frame width in single-line mode so the toast can *animate* between it and
  /// `multilineWidth` when the message crosses the wrap boundary.
  @State private var naturalWidth: CGFloat = 0
  /// Whether the first off-screen measurement has landed. The initial multiline
  /// decision is applied instantly (no entrance wobble); later changes animate.
  @State private var didMeasure = false

  /// Width of a multiline toast: the full device width minus a comfortable
  /// horizontal margin on each side, so it reads clearly inset (like an iOS
  /// notification) rather than edge-to-edge. Capped so it never stretches
  /// unwieldily wide on large screens (iPad / landscape).
  private var multilineWidth: CGFloat {
    ToastMetrics.multilineWidth(deviceWidth: deviceWidth)
  }

  /// Concrete frame width: the multiline width when wrapped, else the measured
  /// hugging width. `nil` only before the first measurement, where it falls back
  /// to hugging via `fixedSize` (the natural width ≈ this, so the hand-off when
  /// the measurement lands is invisible).
  private var resolvedWidth: CGFloat? {
    if isMultiline { return multilineWidth }
    return naturalWidth > 0 ? naturalWidth : nil
  }

  /// True when the toast shows more than one line of text *total* — a wrapped
  /// (multiline) message, or a title above a message. Drives the shape: a
  /// single-line toast is a capsule, multi-line content is a rounded rectangle.
  private var hasMultipleTextLines: Bool {
    isMultiline || (toast.title?.isEmpty == false && !toast.message.isEmpty)
  }

  private var shape: AnyShape {
    // One shape type for every state (so the frame animates across the multiline
    // boundary without the shape snapping). Capsule (a large radius the shape
    // clamps to half the height) when a single line of text is shown; a
    // rounded rectangle when more than one line is — decided on the *total* text
    // (title + message), not the message alone. Width stays hugging until the
    // message itself wraps, so a compact titled toast is a small rounded card.
    let radius = toast.style?.cornerRadius
      ?? (hasMultipleTextLines ? ToastMetrics.multilineCornerRadius : ToastMetrics.capsuleCornerRadius)
    return AnyShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
  }

  private var measurementInputs: ToastMeasurementInputs {
    ToastMeasurementInputs(
      message: toast.message,
      title: toast.title,
      maxLines: toast.maxLines,
      hasAction: toast.action != nil,
      showsLeading: toast.showsLeadingSlot,
      actionWidth: actionWidth,
      multilineWidth: multilineWidth)
  }

  var body: some View {
    ToastContentView(toast: toast, isMultiline: isMultiline, onAction: onAction)
      // Multiline pins to the (capped) near-full width; single-line hugs content
      // — both concrete widths so a morph across the boundary animates.
      .modifier(ToastWidthModifier(width: resolvedWidth))
      .background { GlassBackground(shape: shape, surfaceTint: toast.style?.background?.resolved(scheme)) }
      .overlay(shape.stroke(Color.white.opacity(scheme == .dark ? 0.08 : 0.0), lineWidth: 0.5))
      .contentShape(shape)
      .background(ToastMeasurementProbes(inputs: measurementInputs).equatable())
      .modifier(ShakeEffect(animatableData: shakeProgress))
      .onChange(of: toast.shakeToken) { _, token in
        guard token != 0 else { return }
        // Under Reduce Motion, adopt the token silently (no visible shake).
        if reduceMotion { shakeProgress = CGFloat(token); return }
        withAnimation(ToastMetrics.shakeAnimation) { shakeProgress = CGFloat(token) }
      }
      .offset(y: dragOffset)
      .highPriorityGesture(dragGesture)
      .onTapGesture {
        Haptics.impact(.light)
        onTapBody()
      }
      .simultaneousGesture(
        // Touch-down pauses auto-dismiss, lift resumes it. Runs alongside the
        // swipe (highPriority) and tap gestures without consuming them.
        DragGesture(minimumDistance: 0)
          .onChanged { _ in if !isPressed { isPressed = true; onPressStart() } }
          .onEnded { _ in if isPressed { isPressed = false; onPressEnd() } }
      )
      .onPreferenceChange(ActionWidthKey.self) { actionWidth = $0 }
      .onPreferenceChange(NaturalWidthKey.self) { w in
        // Animate single-line width changes too, so a capsule -> capsule morph
        // (e.g. "Downloading season 2" -> "Download complete") grows/shrinks
        // smoothly. First measurement applies instantly.
        if naturalWidth == 0 {
          naturalWidth = w
        } else if w != naturalWidth {
          withAnimation(ToastMetrics.stackSpring) { naturalWidth = w }
        }
      }
      .onPreferenceChange(MessageHeightKey.self) { height in
        // The multiline decision: if the message needs more than one line at
        // the multiline reference width, commit to the multiline treatment.
        let lineHeight = UIFont.preferredFont(forTextStyle: .subheadline).lineHeight
        let multi = deviceWidth > 0 && height > lineHeight * 1.5
        if !didMeasure {
          isMultiline = multi // first measurement: apply instantly (no entrance wobble)
          didMeasure = true
        } else if multi != isMultiline {
          // A morph (e.g. an upload's progress -> "done") crossed the wrap
          // boundary — animate the width + reflow instead of snapping.
          withAnimation(ToastMetrics.stackSpring) {
            isMultiline = multi
          }
        }
      }
      .accessibilityElement(children: .combine)
      .accessibilityLabel(toast.accessibilityText)
      .accessibilityAddTraits(.isStaticText)
  }

  // MARK: - Drag

  private var dragGesture: some Gesture {
    DragGesture(minimumDistance: ToastMetrics.dragMinDistance)
      .onChanged { value in
        if !isDragging {
          isDragging = true
          Haptics.impact(.light) // drag begins
        }
        let dy = value.translation.height
        let towardEdge = toast.position.isBottom ? dy > 0 : dy < 0
        // Rubber-band drags away from the dismiss edge.
        dragOffset = towardEdge ? dy : dy * ToastMetrics.rubberBandFactor
      }
      .onEnded { value in
        isDragging = false
        let dy = value.translation.height
        // Velocity-aware: a quick flick dismisses even if the finger barely moved.
        let predicted = value.predictedEndTranslation.height
        let towardEdge = toast.position.isBottom ? dy > 0 : dy < 0
        let flick = toast.position.isBottom
          ? predicted > ToastMetrics.flickDistance
          : predicted < -ToastMetrics.flickDistance
        if towardEdge && (abs(dy) > ToastMetrics.dragCommitDistance || flick) {
          Haptics.impact(.medium) // commit
          onSwipe()
        } else {
          withAnimation(ToastMetrics.settleSpring) {
            dragOffset = 0
          }
        }
      }
  }
}

// MARK: - Shake

/// A transient horizontal shake for a group toast re-shown with unchanged text.
/// `animatableData` carries the shake token: it sweeps one whole unit per shake,
/// so rest sits exactly on integers (displacement 0) and the toast always
/// settles centred. Within a unit the offset oscillates [shakeCount] times with
/// a linear amplitude falloff, so it decays to nothing.
private struct ShakeEffect: GeometryEffect {
  var amplitude: CGFloat = ToastMetrics.shakeAmplitude
  var shakeCount: CGFloat = ToastMetrics.shakeCount
  var animatableData: CGFloat

  func effectValue(size: CGSize) -> ProjectionTransform {
    let frac = animatableData - animatableData.rounded(.down)
    let dx = amplitude * (1 - frac) * sin(frac * .pi * 2 * shakeCount)
    return ProjectionTransform(CGAffineTransform(translationX: dx, y: 0))
  }
}

// MARK: - Width

/// Applies a fixed width for multiline toasts, or hugs content (single-line).
/// A plain conditional `.frame`/`.fixedSize` can't be expressed inline because
/// the two branches return different layouts, so it lives in a modifier.
private struct ToastWidthModifier: ViewModifier {
  let width: CGFloat?

  func body(content: Content) -> some View {
    if let width {
      content.frame(width: width)
    } else {
      content.fixedSize(horizontal: true, vertical: false)
    }
  }
}
