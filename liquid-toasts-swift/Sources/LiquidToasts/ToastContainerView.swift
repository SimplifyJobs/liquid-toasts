import SwiftUI

/// Reports each toast's window-space frame up to the manager, so the overlay
/// host can hit-test for pass-through.
struct ToastFramePreferenceKey: PreferenceKey {
  static var defaultValue: [String: CGRect] = [:]
  static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
    value.merge(nextValue()) { _, new in new }
  }
}

/// Root SwiftUI view hosted in the overlay. Each position is an independent
/// **vertical list**: top positions grow downward (newest on top, pushing older
/// ones down); bottom positions grow upward (newest at the bottom). Toasts slide
/// in (~half the top safe-area inset) with a fade + scale, and fade + blur away
/// in place on exit. Respects Reduce Motion.
struct ToastContainerView: View {
  @ObservedObject var manager: ToastManager
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  /// Live width of the overlay host (== device width, the host is full-screen).
  /// Multiline toasts size themselves to a fraction of this.
  @State private var hostWidth: CGFloat = 0

  /// Toasts grouped by position, preserving insertion order — each position is
  /// its own independent list so a bottom toast never disturbs the top list.
  private var groups: [(position: ToastPositionModel, toasts: [ToastModel])] {
    var order: [ToastPositionModel] = []
    var map: [ToastPositionModel: [ToastModel]] = [:]
    for toast in manager.toasts {
      if map[toast.position] == nil { order.append(toast.position) }
      map[toast.position, default: []].append(toast)
    }
    return order.map { (position: $0, toasts: map[$0]!) }
  }

  var body: some View {
    // No .ignoresSafeArea(): the host view is pinned full-screen, so SwiftUI's
    // safe area places top toasts just below the Dynamic Island and bottom
    // toasts above the home indicator automatically.
    ZStack {
      Color.clear
        .background(
          GeometryReader { geo in
            Color.clear
              .onAppear { hostWidth = geo.size.width }
              .onChange(of: geo.size.width) { _, w in hostWidth = w }
          }
        )
      ForEach(groups, id: \.position) { group in
        positionedList(position: group.position, toasts: group.toasts)
      }
    }
    .animation(motion, value: manager.stackGeneration)
    .onPreferenceChange(ToastFramePreferenceKey.self) { frames in
      manager.frames = frames
    }
  }

  @ViewBuilder
  private func positionedList(position: ToastPositionModel, toasts: [ToastModel]) -> some View {
    // Top lists show newest first (on top); bottom lists show newest last.
    let ordered = position.isBottom ? toasts : toasts.reversed()
    let safeArea = manager.effectiveSafeArea
    let customPadding = manager.customSafeAreaPadding
    VStack(alignment: position.horizontalAlignment, spacing: 10) {
      // Keyed by `identity`, not `id`: a group re-show with unchanged text keeps
      // the same identity while swapping the wire id, so the row shakes in place
      // instead of exit+entering.
      ForEach(ordered, id: \.identity) { toast in
        ToastRow(
          toast: toast,
          deviceWidth: hostWidth,
          entranceDistance: max(16, safeArea.top * 0.5),
          onTapBody: { manager.handleBodyTap(id: toast.id) },
          onAction: { manager.handleAction(id: toast.id) },
          onSwipe: { manager.handleSwipe(id: toast.id) },
          onPressStart: { manager.pauseAutoDismiss(id: toast.id) },
          onPressEnd: { manager.resumeAutoDismiss(id: toast.id) }
        )
        .equatable()
        // Entrance is driven by EntranceView's onAppear so even the first toast
        // (before the container has a prior render) animates. Only removal uses
        // a SwiftUI transition.
        .transition(.asymmetric(
          insertion: .identity,
          removal: reduceMotion ? .opacity : .fadeBlurOut
        ))
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: position.alignment)
    .padding(.top, customPadding.top + 8)
    .padding(.bottom, customPadding.bottom + 8)
    .padding(.leading, customPadding.left + 12)
    .padding(.trailing, customPadding.right + 12)
  }

  private var motion: Animation? {
    reduceMotion ? .easeInOut(duration: 0.2) : ToastMetrics.stackSpring
  }
}

// MARK: - Row

/// One toast row (entrance wrapper + ToastView + frame reporter), equality-
/// gated so a change to one toast doesn't re-render its siblings: with
/// `.equatable()`, SwiftUI skips the body when `==` holds. Environment
/// changes (color scheme, Reduce Motion) and internal `@State` correctly
/// bypass the gate, and preferences keep propagating from skipped subtrees.
private struct ToastRow: View, Equatable {
  let toast: ToastModel
  let deviceWidth: CGFloat
  let entranceDistance: CGFloat
  let onTapBody: () -> Void
  let onAction: () -> Void
  let onSwipe: () -> Void
  let onPressStart: () -> Void
  let onPressEnd: () -> Void

  // Closures are excluded from equality: they capture only the singleton
  // manager and toast.id, and id participates in toast equality — a row can
  // never keep a stale closure for a different toast.
  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.toast == rhs.toast
      && lhs.deviceWidth == rhs.deviceWidth
      && lhs.entranceDistance == rhs.entranceDistance
  }

  var body: some View {
    EntranceView(top: toast.position.isTop, distance: entranceDistance) {
      ToastView(
        toast: toast,
        deviceWidth: deviceWidth,
        onTapBody: onTapBody,
        onAction: onAction,
        onSwipe: onSwipe,
        onPressStart: onPressStart,
        onPressEnd: onPressEnd
      )
      .background(
        GeometryReader { geo in
          Color.clear.preference(
            key: ToastFramePreferenceKey.self,
            value: [toast.id: geo.frame(in: .global)]
          )
        }
      )
    }
  }
}

// MARK: - Entrance

/// Slides a toast in from `distance` away (down for top, up for bottom) while
/// fading + scaling up. Driven by `onAppear` state (not a SwiftUI transition) so
/// even the very first toast — before the container has a prior render — animates.
private struct EntranceView<Content: View>: View {
  let top: Bool
  let distance: CGFloat
  let content: Content

  init(top: Bool, distance: CGFloat, @ViewBuilder content: () -> Content) {
    self.top = top
    self.distance = distance
    self.content = content()
  }

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var shown = false

  var body: some View {
    let active = !shown && !reduceMotion
    content
      .opacity(active ? 0 : 1)
      .scaleEffect(active ? 0.9 : 1)
      .offset(y: active ? (top ? -distance : distance) : 0)
      .onAppear {
        if reduceMotion { shown = true; return }
        // Defer one runloop so the view renders in the offset state first, then
        // springs to identity (a same-transaction set would snap).
        DispatchQueue.main.async {
          withAnimation(ToastMetrics.stackSpring) { shown = true }
        }
      }
  }
}

// MARK: - Transitions

extension AnyTransition {
  /// Exit: scale + fade + blur away **in place** (no offset) — used for a
  /// dismissed toast and for one pushed out of the list.
  static var fadeBlurOut: AnyTransition {
    .modifier(
      active: FadeBlurModifier(scale: 0.86, opacity: 0, blur: 9),
      identity: FadeBlurModifier(scale: 1, opacity: 1, blur: 0)
    )
  }
}

private struct FadeBlurModifier: ViewModifier {
  let scale: CGFloat
  let opacity: Double
  let blur: CGFloat
  func body(content: Content) -> some View {
    content
      .opacity(opacity)
      .scaleEffect(scale)
      .blur(radius: blur)
  }
}
