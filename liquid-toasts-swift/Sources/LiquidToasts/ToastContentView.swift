import SwiftUI
import UIKit

/// The toast's row content: leading slot (avatar / progress ring / icon), the
/// text column (title, message, optional linear progress), and the optional
/// action button — with the insets for the current (single-line vs multiline)
/// treatment.
struct ToastContentView: View {
  let toast: ToastModel
  let isMultiline: Bool
  let onAction: () -> Void

  @Environment(\.colorScheme) private var scheme

  private var foreground: Color {
    toast.style?.foreground?.resolved(scheme) ?? .primary
  }

  /// Accent for the progress ring / bar: the icon-color override, then the tint,
  /// then the semantic color (falling back to the accent for `.none`).
  private var accentTint: Color {
    if let c = toast.style?.iconColor?.resolved(scheme) { return c }
    if let c = toast.style?.tint?.resolved(scheme) { return c }
    return toast.semantic == .none ? .accentColor : toast.semantic.tint
  }

  /// Center the text on a compact, text-only toast: no leading glyph, no
  /// trailing action, and not the full-width multiline layout.
  private var centerText: Bool {
    !toast.showsLeadingSlot && toast.action == nil && !isMultiline
  }

  /// The row spans more than one content line — a wrapped (multiline) message, a
  /// title above the message, or an action button taller than the glyph. Drives
  /// the roomier leading inset so a vertically-centered glyph doesn't hug the
  /// left edge.
  private var tallRow: Bool {
    isMultiline || toast.action != nil
      || (toast.title?.isEmpty == false && !toast.message.isEmpty)
  }

  var body: some View {
    // Icon and action stay vertically centered against the (possibly tall)
    // text column.
    HStack(alignment: .center, spacing: ToastMetrics.rowSpacing(multiline: isMultiline)) {
      if toast.expectsImage || toast.image != nil {
        AvatarSlot(image: toast.image?.uiImage)
      } else if toast.showsCircularProgress {
        CircularProgressView(value: toast.progress ?? 0, tint: accentTint)
      } else if toast.showsIcon {
        IconView(toast: toast)
      }

      VStack(alignment: centerText ? .center : .leading, spacing: 2) {
        if let title = toast.title, !title.isEmpty {
          Text(title)
            .font(.system(.subheadline, design: .rounded).weight(.semibold))
            .foregroundStyle(foreground)
            .multilineTextAlignment(centerText ? .center : .leading)
            .lineLimit(toast.titleMaxLines)
            .fixedSize(horizontal: false, vertical: true)
        }
        if !toast.message.isEmpty {
          Text(toast.message)
            .font(.system(.subheadline, design: .rounded))
            .foregroundStyle(toast.title == nil ? foreground : foreground.opacity(0.85))
            .multilineTextAlignment(centerText ? .center : .leading)
            .lineLimit(toast.maxLines)
            .fixedSize(horizontal: false, vertical: true)
        }

        if let progress = toast.progress, toast.progressStyle == .linear {
          ProgressView(value: max(0, min(1, progress)))
            .progressViewStyle(.linear)
            .tint(accentTint)
            // Fills the text column when multiline; fixed on a hugging capsule.
            .frame(maxWidth: isMultiline ? .infinity : ToastMetrics.linearProgressWidth)
            .padding(.top, 4)
        }
      }
      // Single-line caps the text column so the capsule never spans the screen;
      // multiline fills the fixed-width rounded rect.
      .frame(
        maxWidth: isMultiline ? .infinity : ToastMetrics.textColumnMaxWidth,
        alignment: centerText ? .center : .leading)

      if let action = toast.action {
        ActionButton(action: action, isLoading: toast.isActionBusy, onTap: onAction)
          .background(GeometryReader { g in
            Color.clear.preference(key: ActionWidthKey.self, value: g.size.width)
          })
      }
    }
    .padding(.leading,
             ToastMetrics.leadingPadding(multiline: isMultiline, hasLeadingSlot: toast.showsLeadingSlot, tallRow: tallRow))
    .padding(.trailing,
             ToastMetrics.trailingPadding(multiline: isMultiline, hasAction: toast.action != nil))
    .padding(.vertical, ToastMetrics.verticalPadding(multiline: isMultiline))
  }
}

// MARK: - Circular progress

/// A determinate circular progress ring sized to the leading icon slot — an
/// upload/download-style indicator. (SwiftUI's `.circular` progress style is
/// indeterminate on iOS, so the arc is drawn directly.)
struct CircularProgressView: View {
  let value: Double
  let tint: Color

  var body: some View {
    let clamped = max(0, min(1, value))
    ZStack {
      Circle()
        .stroke(tint.opacity(0.22), lineWidth: 2.6)
      Circle()
        .trim(from: 0, to: clamped)
        .stroke(tint, style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
        .rotationEffect(.degrees(-90))
        .animation(.easeInOut(duration: 0.25), value: clamped)
    }
    .frame(width: ToastMetrics.progressRingSize, height: ToastMetrics.progressRingSize)
  }
}

// MARK: - Avatar

/// Reserves the avatar footprint from the first frame; the pixels land
/// whenever the off-main decode finishes (usually within the entrance), so
/// the row never shifts.
struct AvatarSlot: View {
  let image: UIImage?

  var body: some View {
    if let image {
      AvatarView(image: image)
    } else {
      Color.clear
        .frame(width: ToastMetrics.avatarSize, height: ToastMetrics.avatarSize)
    }
  }
}

/// A circular avatar / thumbnail in the leading slot — a raster image passed
/// from Dart (any `ImageProvider`, resolved to bytes), in place of the SF Symbol.
struct AvatarView: View {
  let image: UIImage

  var body: some View {
    Image(uiImage: image)
      .resizable()
      .scaledToFill()
      .frame(width: ToastMetrics.avatarSize, height: ToastMetrics.avatarSize)
      .clipShape(Circle())
      .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 0.5))
  }
}
