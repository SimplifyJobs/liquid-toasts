/// Where a toast anchors on screen.
///
/// The **Dynamic Island origin** animation is only used for [topCenter] on
/// devices that have a Dynamic Island (and in portrait). Every other position —
/// and [topCenter] on notch / home-button devices — uses a standard slide-in
/// from the nearest screen edge.
enum ToastPosition {
  topCenter,
  topLeading,
  topTrailing,
  center,
  bottomCenter,
  bottomLeading,
  bottomTrailing,
}

/// Convenience helpers for the platform side and layout decisions.
extension ToastPositionX on ToastPosition {
  bool get isTop =>
      this == ToastPosition.topCenter ||
      this == ToastPosition.topLeading ||
      this == ToastPosition.topTrailing;

  bool get isBottom =>
      this == ToastPosition.bottomCenter ||
      this == ToastPosition.bottomLeading ||
      this == ToastPosition.bottomTrailing;
}
