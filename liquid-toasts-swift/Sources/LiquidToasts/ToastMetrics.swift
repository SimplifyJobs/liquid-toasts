import SwiftUI

/// Single source for every shared layout constant and spring in the toast
/// render tree. The off-screen measurement probes must mirror the live
/// layout's insets exactly or the wrap/width decisions drift — routing every
/// value through here makes that lockstep structural instead of copy-paste.
enum ToastMetrics {
  // MARK: Row insets (multiline gets roomier insets than the hugging capsule)

  private static func baseHorizontalPadding(multiline: Bool) -> CGFloat { multiline ? 18 : 16 }
  static func verticalPadding(multiline: Bool) -> CGFloat { multiline ? 14 : 11 }

  /// Roomier leading inset for a *tall* row so a vertically-centered glyph reads
  /// symmetric with the top/bottom gap instead of hugging the left edge.
  static let tallRowLeadingPadding: CGFloat = 20

  /// Leading inset for the icon/avatar slot. A plain single-line toast pins the
  /// glyph snugly (matching the vertical inset), so left/top/bottom read even.
  /// But when the row is *tall* — more than one content line — the vertically
  /// centered glyph would sit closer to the left edge than to the top/bottom, so
  /// it gets a roomier inset. A row is tall when [tallRow] is set: a multiline
  /// (wrapped) message, a title above a message (two lines), or an action button
  /// (taller than the glyph). Computed by the caller so the live view and the
  /// off-screen probes agree.
  static func leadingPadding(multiline: Bool, hasLeadingSlot: Bool, tallRow: Bool) -> CGFloat {
    guard hasLeadingSlot else { return baseHorizontalPadding(multiline: multiline) }
    return tallRow ? tallRowLeadingPadding : verticalPadding(multiline: multiline)
  }

  /// Trailing inset. With an action present it matches the (tighter) button
  /// margin; otherwise it mirrors the base horizontal inset (independent of
  /// the leading slot, so the text-side edge stays symmetric).
  static func trailingPadding(multiline: Bool, hasAction: Bool) -> CGFloat {
    hasAction ? 11 : baseHorizontalPadding(multiline: multiline)
  }

  /// Spacing between the icon, the text column, and the action.
  static func rowSpacing(multiline: Bool) -> CGFloat { multiline ? 14 : 12 }

  // MARK: Slots & column widths

  /// Leading glyph slot (spinner / SF Symbol / progress ring).
  static let iconSlot: CGFloat = 22
  /// Determinate progress ring diameter (sits inside the icon slot).
  static let progressRingSize: CGFloat = 20
  /// Leading avatar / thumbnail diameter.
  static let avatarSize: CGFloat = 26
  /// Single-line text column cap so the capsule never spans the screen.
  static let textColumnMaxWidth: CGFloat = 260
  /// Fixed linear progress bar width on a hugging capsule.
  static let linearProgressWidth: CGFloat = 160
  /// Estimated action button width until its first real measurement lands.
  static let actionWidthEstimate: CGFloat = 72
  /// Floor for the multiline probe's reference text width.
  static let probeMinReferenceWidth: CGFloat = 120

  // MARK: Multiline geometry

  static let multilineSideMargin: CGFloat = 20
  static let multilineMaxWidth: CGFloat = 440

  /// Width of a multiline toast: near-full device width, comfortably inset,
  /// capped so it never stretches unwieldily wide on iPad / landscape.
  static func multilineWidth(deviceWidth: CGFloat) -> CGFloat {
    min(multilineMaxWidth, deviceWidth - multilineSideMargin * 2)
  }

  // MARK: Shape

  /// Corner radius for a wrapped multiline toast — a rounded rectangle.
  static let multilineCornerRadius: CGFloat = 22
  /// Corner radius for a single-line toast (title and/or message on one line):
  /// a large radius the shape clamps to half the height, so it reads as a capsule
  /// regardless of how tall a title + message makes it.
  static let capsuleCornerRadius: CGFloat = 99

  // MARK: Drag

  static let dragMinDistance: CGFloat = 6
  /// Translation past which a drag toward the edge commits to dismissal.
  static let dragCommitDistance: CGFloat = 28
  /// Predicted end translation past which a flick commits regardless of travel.
  static let flickDistance: CGFloat = 140
  /// Damping applied when dragging away from the dismiss edge.
  static let rubberBandFactor: CGFloat = 0.35

  // MARK: Springs

  /// The stack's shared motion: entrances, reorders, morphs, width changes.
  static let stackSpring: Animation = .spring(response: 0.42, dampingFraction: 0.82)
  /// Snappier settle: drag return, icon swaps.
  static let settleSpring: Animation = .spring(response: 0.35, dampingFraction: 0.7)

  // MARK: Shake (group re-show with unchanged text)

  /// Peak horizontal displacement of the in-place shake.
  static let shakeAmplitude: CGFloat = 7
  /// Left-right oscillations per shake.
  static let shakeCount: CGFloat = 3
  /// Time base for the shake — linear, so the sine + amplitude falloff (not the
  /// easing curve) shape the motion.
  static let shakeAnimation: Animation = .linear(duration: 0.45)
}
