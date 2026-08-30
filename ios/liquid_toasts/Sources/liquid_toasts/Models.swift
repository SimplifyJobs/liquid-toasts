import SwiftUI
import UIKit

// MARK: - Enums (raw values mirror the Dart `.name` wire format)

/// Built-in semantic intent: drives the default symbol, tint, duration,
/// line cap and appear-haptic (see `SemanticDefaults`).
///
/// Raw values are wire strings shared with the Flutter bridge — see the
/// wire-protocol invariants in CLAUDE.md.
public enum ToastSemantic: String, Sendable {
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

/// Requested glass treatment. The real decision (native Liquid Glass on
/// iOS 26+, frosted material below, opaque under Reduce Transparency) is made
/// at render time; this only expresses intent.
public enum ToastGlassIntent: String, Sendable { case adaptive, liquid, frosted, solid, none }

/// Whether the toast renders a spinner (`loading`) or static content.
public enum ToastContentState: String, Sendable { case `static`, loading }

/// Haptic fired when the toast appears.
public enum ToastHapticKind: String, Sendable { case none, success, warning, error, selection }

/// Animated effect applied to the toast's SF Symbol. Effects unavailable on the
/// running OS degrade gracefully (see `IconView`).
public enum ToastSymbolEffect: String, Sendable {
  case none, bounce, pulse, wiggle, rotate, breathe, variableColor, drawOn
}

/// How a determinate progress value renders: a bar under the text, or a ring in
/// the leading slot (in place of the icon).
public enum ToastProgressStyle: String, Sendable { case linear, circular }

/// Where a toast anchors. Each position is an independent vertical stack.
public enum ToastPositionModel: String, Sendable {
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

/// Semantic role of the action button. The color is derived from the role
/// (adaptive) unless `ToastActionModel.color` overrides it.
public enum ToastActionRole: String, Sendable {
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
/// scheme — the context-free equivalent of a dynamic system color.
public struct ToastColor: Equatable {
  public let light: Color
  public let dark: Color

  /// A pair that resolves per color scheme. Pass the same value twice for a
  /// frozen (non-adaptive) color.
  public init(light: Color, dark: Color) {
    self.light = light
    self.dark = dark
  }

  func resolved(_ scheme: ColorScheme) -> Color { scheme == .dark ? dark : light }
}

// MARK: - Style / Action models

/// Per-toast visual override. Every field is null-means-inherit: anything left
/// nil falls back to the semantic-derived value computed at render time.
public struct ToastStyleModel: Equatable {
  /// Accent tint — colors the icon, spinner and progress indicator, never the
  /// surface.
  public var tint: ToastColor?
  /// Surface color. Tints the glass on iOS 26+, fills the surface below.
  public var background: ToastColor?
  /// Title + message color.
  public var foreground: ToastColor?
  /// Icon color (defaults to the tint / semantic color).
  public var iconColor: ToastColor?
  public var glass: ToastGlassIntent?
  /// nil lets the renderer choose (capsule when compact, rounded rect when not).
  public var cornerRadius: CGFloat?
  public var symbolEffect: ToastSymbolEffect = .none

  public init(
    tint: ToastColor? = nil,
    background: ToastColor? = nil,
    foreground: ToastColor? = nil,
    iconColor: ToastColor? = nil,
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

/// The single (at most one) action button on a toast.
///
/// Low-level: this is the *rendered* description only. The press callback never
/// lives here — the renderer reports `actionId` back through the event stream
/// and the owning facade (Dart's engine, or `LiquidToast` natively) runs the
/// closure it kept keyed by id.
public struct ToastActionModel: Equatable {
  /// Correlates an `actionTapped` event back to the caller's closure. A facade
  /// mints a fresh one on every content change so a tap that raced an update is
  /// dropped instead of invoking the superseded action.
  public let actionId: String
  public let label: String
  public let role: ToastActionRole
  public let color: ToastColor?
  /// Whether the toast dismisses itself once the tap is delivered.
  public let dismissOnPress: Bool
  /// Whether pressing swaps the label for a spinner and keeps the toast up
  /// until the facade calls `ToastManager.finishAction(id:)` (or dismisses it).
  public let loadingOnPress: Bool

  public init(
    actionId: String,
    label: String,
    role: ToastActionRole = .primary,
    color: ToastColor? = nil,
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
public struct ToastImage: Equatable {
  public let uiImage: UIImage

  public init(uiImage: UIImage) { self.uiImage = uiImage }

  public static func == (lhs: ToastImage, rhs: ToastImage) -> Bool {
    lhs.uiImage === rhs.uiImage
  }
}

/// The rendered description of one toast — the single value the overlay draws
/// from, and the native mirror of Dart's `Toast`.
///
/// Low-level: prefer the `LiquidToast` facade, which assembles these (and owns
/// the callbacks) for you. Build one directly only when driving
/// [ToastManager] yourself.
public struct ToastModel: Identifiable, Equatable {
  /// Opaque, caller-minted id. Used for events, frames and timers; it is what
  /// every [ToastManager] entry point addresses.
  public let id: String

  /// The SwiftUI view identity of this toast's row — normally the same as [id],
  /// but held stable across an in-place group re-show (a "shake") so the row
  /// morphs/shakes instead of exit+entering. Distinct from [id], which is the
  /// wire id used for events, frames, and the auto-dismiss timer.
  public internal(set) var identity: String

  /// Bumped each time an already-visible group toast is re-shown with unchanged
  /// text: the row observes the change and plays a one-shot horizontal shake.
  /// Runtime-only (never decoded from the wire).
  public internal(set) var shakeToken: Int = 0
  public var message: String
  public var title: String?
  /// SF Symbol name. When nil the symbol is derived from [semantic].
  public var icon: String?

  /// The decoded leading image. Arrives asynchronously (decode happens off the
  /// main thread) — nil until then, and stays nil for toasts without one.
  public var image: ToastImage?

  /// True when the caller supplied image bytes. Reserves the avatar slot
  /// from the first frame so the layout doesn't jump when the decoded pixels
  /// land; the manager clears it if the decode fails (the slot then collapses).
  public var expectsImage: Bool
  public var semantic: ToastSemantic
  public var style: ToastStyleModel?
  public var position: ToastPositionModel
  public var state: ToastContentState
  public var persistent: Bool
  public var durationMs: Int?
  public var useDynamicIslandOrigin: Bool
  public var progress: Double?
  public var progressStyle: ToastProgressStyle
  /// De-dup / replace key: presenting a toast whose key matches a live one
  /// morphs that toast in place instead of stacking a duplicate.
  public var groupKey: String?
  public var haptic: ToastHapticKind
  public var semanticsLabel: String?
  public var maxLines: Int
  public var titleMaxLines: Int
  public var tapToDismiss: Bool
  /// Whether the owner wants `tapped` events for this toast. The tap callback
  /// itself lives facade-side, keyed by [id].
  public var hasTap: Bool
  public var action: ToastActionModel?

  /// Runtime-only, never decoded from the wire: true while the action's async
  /// `onPressed` runs — the button shows a spinner. Lives on the model (like
  /// `progress`) so flipping it re-renders only the affected row.
  public internal(set) var isActionBusy = false

  /// Builds a toast. Defaults mirror the wire defaults (see the decoding
  /// extension in `WireModels.swift`), so a payload that omits a key and a
  /// caller that omits the argument produce the same toast.
  ///
  /// Image pixels can be passed here directly ([image]); a caller holding
  /// undecoded bytes instead hands the raw `Data` to
  /// `ToastManager.present(_:imageData:)`, which decodes off the main thread
  /// and attaches the result — set [expectsImage] so the slot is reserved from
  /// the first frame.
  public init(
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
