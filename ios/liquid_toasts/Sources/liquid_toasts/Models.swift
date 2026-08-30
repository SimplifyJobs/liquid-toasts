import SwiftUI
import UIKit

// MARK: - Enums (raw values mirror the Dart `.name` wire format)

enum ToastSemantic: String {
  case success, error, warning, info, none

  /// Default SF Symbol for this intent (nil for `.none`).
  var defaultSymbol: String? {
    switch self {
    case .success: return "checkmark.circle.fill"
    case .error: return "xmark.octagon.fill"
    case .warning: return "exclamationmark.triangle.fill"
    case .info: return "info.circle.fill"
    case .none: return nil
    }
  }

  /// Adaptive accent color (system colors auto-adapt to light/dark).
  var tint: Color {
    switch self {
    case .success: return .green
    case .error: return .red
    case .warning: return .orange
    case .info: return .blue
    case .none: return .secondary
    }
  }
}

enum ToastGlassIntent: String { case adaptive, liquid, frosted, solid, none }

enum ToastContentState: String { case `static`, loading }

enum ToastHapticKind: String { case none, success, warning, error, selection }

enum ToastSymbolEffect: String {
  case none, bounce, pulse, wiggle, rotate, breathe, variableColor, drawOn
}

enum ToastProgressStyle: String { case linear, circular }

enum ToastPositionModel: String {
  case topCenter, topLeading, topTrailing
  case center
  case bottomCenter, bottomLeading, bottomTrailing

  var isTop: Bool { self == .topCenter || self == .topLeading || self == .topTrailing }
  var isBottom: Bool { self == .bottomCenter || self == .bottomLeading || self == .bottomTrailing }

  var alignment: Alignment {
    switch self {
    case .topCenter: return .top
    case .topLeading: return .topLeading
    case .topTrailing: return .topTrailing
    case .center: return .center
    case .bottomCenter: return .bottom
    case .bottomLeading: return .bottomLeading
    case .bottomTrailing: return .bottomTrailing
    }
  }

  var horizontalAlignment: HorizontalAlignment {
    switch self {
    case .topLeading, .bottomLeading: return .leading
    case .topTrailing, .bottomTrailing: return .trailing
    default: return .center
    }
  }
}

enum ActionRole: String {
  case primary, secondary, destructive, success, warning, neutral

  var color: Color {
    switch self {
    case .primary: return .accentColor
    case .secondary: return .secondary
    case .destructive: return .red
    case .success: return .green
    case .warning: return .orange
    case .neutral: return Color.primary.opacity(0.7)
    }
  }
}

// MARK: - Color

/// A `{light, dark}` color pair, resolved natively against the current color
/// scheme.
struct AdaptiveColor: Equatable {
  let light: Color
  let dark: Color

  init(light: Color, dark: Color) {
    self.light = light
    self.dark = dark
  }

  func resolved(_ scheme: ColorScheme) -> Color { scheme == .dark ? dark : light }
}

// MARK: - Style / Action models

struct ToastStyleModel: Equatable {
  var tint: AdaptiveColor?
  var background: AdaptiveColor?
  var foreground: AdaptiveColor?
  var iconColor: AdaptiveColor?
  var glass: ToastGlassIntent?
  var cornerRadius: CGFloat?
  var symbolEffect: ToastSymbolEffect = .none

  init(
    tint: AdaptiveColor? = nil,
    background: AdaptiveColor? = nil,
    foreground: AdaptiveColor? = nil,
    iconColor: AdaptiveColor? = nil,
    glass: ToastGlassIntent? = nil,
    cornerRadius: CGFloat? = nil,
    symbolEffect: ToastSymbolEffect = .none
  ) {
    self.tint = tint
    self.background = background
    self.foreground = foreground
    self.iconColor = iconColor
    self.glass = glass
    self.cornerRadius = cornerRadius
    self.symbolEffect = symbolEffect
  }
}

struct ToastActionModel: Equatable {
  let actionId: String
  let label: String
  let role: ActionRole
  let color: AdaptiveColor?
  let dismissOnPress: Bool
  let loadingOnPress: Bool

  init(
    actionId: String,
    label: String,
    role: ActionRole = .primary,
    color: AdaptiveColor? = nil,
    dismissOnPress: Bool = true,
    loadingOnPress: Bool = false
  ) {
    self.actionId = actionId
    self.label = label
    self.role = role
    self.color = color
    self.dismissOnPress = dismissOnPress
    self.loadingOnPress = loadingOnPress
  }
}

// MARK: - Toast model

/// Reference-equality wrapper so [ToastModel] can synthesize `==` without
/// ever comparing pixel data — a decoded image is immutable, so identity is
/// the right equivalence.
struct ToastImage: Equatable {
  let uiImage: UIImage
  static func == (lhs: ToastImage, rhs: ToastImage) -> Bool {
    lhs.uiImage === rhs.uiImage
  }
}

struct ToastModel: Identifiable, Equatable {
  let id: String

  /// The SwiftUI view identity of this toast's row — normally the same as [id],
  /// but held stable across an in-place group re-show (a "shake") so the row
  /// morphs/shakes instead of exit+entering. Distinct from [id], which is the
  /// wire id used for events, frames, and the auto-dismiss timer.
  var identity: String

  /// Bumped each time an already-visible group toast is re-shown with unchanged
  /// text: the row observes the change and plays a one-shot horizontal shake.
  /// Runtime-only (never decoded from the wire).
  var shakeToken: Int = 0
  var message: String
  var title: String?
  var icon: String?

  /// The decoded leading image. Arrives asynchronously (decode happens off the
  /// main thread) — nil until then, and stays nil for toasts without one.
  var image: ToastImage?

  /// True when the caller supplied image bytes. Reserves the avatar slot
  /// from the first frame so the layout doesn't jump when the decoded pixels
  /// land; the manager clears it if the decode fails (the slot then collapses).
  var expectsImage: Bool
  var semantic: ToastSemantic
  var style: ToastStyleModel?
  var position: ToastPositionModel
  var state: ToastContentState
  var persistent: Bool
  var durationMs: Int?
  var useDynamicIslandOrigin: Bool
  var progress: Double?
  var progressStyle: ToastProgressStyle
  var groupKey: String?
  var haptic: ToastHapticKind
  var semanticsLabel: String?
  var maxLines: Int
  var titleMaxLines: Int
  var tapToDismiss: Bool
  var hasTap: Bool
  var action: ToastActionModel?

  /// Runtime-only, never decoded from the wire: true while the action's async
  /// `onPressed` runs — the button shows a spinner. Lives on the model (like
  /// `progress`) so flipping it re-renders only the affected row.
  var isActionBusy = false

  /// Builds a toast. Defaults mirror the wire defaults (see the decoding
  /// extension in `WireModels.swift`), so a payload that omits a key and a
  /// caller that omits the argument produce the same toast.
  ///
  /// Image pixels are never passed here: the caller hands the raw `Data` to
  /// `ToastManager.present(_:imageData:)`, which decodes off the main thread
  /// and attaches the result. Set [expectsImage] so the slot is reserved from
  /// the first frame.
  init(
    id: String,
    message: String,
    identity: String? = nil,
    title: String? = nil,
    icon: String? = nil,
    image: ToastImage? = nil,
    expectsImage: Bool = false,
    semantic: ToastSemantic = .none,
    style: ToastStyleModel? = nil,
    position: ToastPositionModel = .topCenter,
    state: ToastContentState = .static,
    persistent: Bool = false,
    durationMs: Int? = nil,
    useDynamicIslandOrigin: Bool = true,
    progress: Double? = nil,
    progressStyle: ToastProgressStyle = .linear,
    groupKey: String? = nil,
    haptic: ToastHapticKind = .none,
    semanticsLabel: String? = nil,
    maxLines: Int = 1,
    titleMaxLines: Int = 1,
    tapToDismiss: Bool = true,
    hasTap: Bool = false,
    action: ToastActionModel? = nil
  ) {
    self.id = id
    self.identity = identity ?? id
    self.message = message
    self.title = title
    self.icon = icon
    self.image = image
    self.expectsImage = expectsImage
    self.semantic = semantic
    self.style = style
    self.position = position
    self.state = state
    self.persistent = persistent
    self.durationMs = durationMs
    self.useDynamicIslandOrigin = useDynamicIslandOrigin
    self.progress = progress
    self.progressStyle = progressStyle
    self.groupKey = groupKey
    self.haptic = haptic
    self.semanticsLabel = semanticsLabel
    self.maxLines = maxLines
    self.titleMaxLines = titleMaxLines
    self.tapToDismiss = tapToDismiss
    self.hasTap = hasTap
    self.action = action
  }

  /// Applies a fresh decode's content onto this toast, preserving identity so
  /// SwiftUI morphs the existing capsule instead of swapping it.
  mutating func applyContent(from other: ToastModel) {
    message = other.message
    title = other.title
    icon = other.icon
    image = other.image
    expectsImage = other.expectsImage
    semantic = other.semantic
    style = other.style
    position = other.position
    state = other.state
    persistent = other.persistent
    durationMs = other.durationMs
    progress = other.progress
    progressStyle = other.progressStyle
    haptic = other.haptic
    semanticsLabel = other.semanticsLabel
    maxLines = other.maxLines
    titleMaxLines = other.titleMaxLines
    tapToDismiss = other.tapToDismiss
    hasTap = other.hasTap
    action = other.action
    // A morph supersedes any in-flight action spinner.
    isActionBusy = false
  }

  /// The SF Symbol to render: explicit icon wins, else the semantic default.
  var resolvedSymbol: String? {
    if let icon = icon, !icon.isEmpty { return icon }
    return semantic.defaultSymbol
  }

  // MARK: Leading-slot flags (single source for the content row AND the
  // measurement probes, so their layouts can't disagree)

  /// Whether a leading glyph (spinner or SF Symbol) renders. When false the
  /// icon is dropped from the row entirely — slot and spacing — so a text-only
  /// toast hugs its leading padding instead of reserving an empty icon box.
  var showsIcon: Bool { state == .loading || resolvedSymbol != nil }

  /// A determinate circular progress ring renders in place of the leading icon.
  var showsCircularProgress: Bool { progress != nil && progressStyle == .circular }

  /// Whether anything occupies the leading slot (image / ring / spinner / icon).
  /// Keys off [expectsImage] (not just decoded pixels) so the slot is stable
  /// from the first frame while the async decode runs.
  var showsLeadingSlot: Bool {
    expectsImage || image != nil || showsCircularProgress || showsIcon
  }

  /// Auto-dismiss interval, or nil when persistent / loading.
  var autoDuration: TimeInterval? {
    if persistent || state == .loading { return nil }
    let ms = durationMs ?? 3000
    let clamped = min(max(ms, 1500), 10000)
    return TimeInterval(clamped) / 1000.0
  }

  var accessibilityText: String {
    if let label = semanticsLabel, !label.isEmpty { return label }
    return [title, message].compactMap { $0 }.joined(separator: ", ")
  }
}
