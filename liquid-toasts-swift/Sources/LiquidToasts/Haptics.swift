import UIKit

/// Thin wrapper around UIKit feedback generators, shared across the toast views
/// and the manager.
enum Haptics {
  static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
    UIImpactFeedbackGenerator(style: style).impactOccurred()
  }

  static func selection() {
    UISelectionFeedbackGenerator().selectionChanged()
  }

  static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
    UINotificationFeedbackGenerator().notificationOccurred(type)
  }
}
