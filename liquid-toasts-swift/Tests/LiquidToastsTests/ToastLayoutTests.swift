import SwiftUI
import UIKit
import XCTest
@testable import LiquidToasts

@MainActor
final class ToastLayoutTests: XCTestCase {
  func testLeadingSlotTracksActualContent() {
    XCTAssertEqual(ToastModel(id: "text", message: "Hello").leadingSlotWidth, 0)
    XCTAssertEqual(ToastModel(id: "icon", message: "Hello", icon: "paperplane").leadingSlotWidth,
      ToastMetrics.iconSlot)
    XCTAssertEqual(ToastModel(id: "avatar", message: "Hello", expectsImage: true).leadingSlotWidth,
      ToastMetrics.avatarSize)
    XCTAssertEqual(ToastModel(id: "progress", message: "Hello", progress: 0.5,
      progressStyle: .circular).leadingSlotWidth, ToastMetrics.progressRingSize)
  }

  func testAvatarTitleAndSubtitleStayOnOneLineEach() {
    let toast = ToastModel(id: "submitted", message: "Tap to track progress.",
      title: "Queued for Autopilot", icon: "paperplane", expectsImage: true,
      maxLines: 3, titleMaxLines: 2)
    var measuredWidth: CGFloat = 0
    let probe = ToastMeasurementProbes(inputs: ToastMeasurementInputs(
      message: toast.message, title: toast.title, maxLines: toast.maxLines,
      hasAction: false, leadingSlotWidth: toast.leadingSlotWidth, actionWidth: 0,
      multilineWidth: ToastMetrics.multilineWidth(deviceWidth: 402)))
      .onPreferenceChange(NaturalWidthKey.self) { measuredWidth = $0 }
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
    let host = UIHostingController(rootView: probe)
    window.rootViewController = host
    window.makeKeyAndVisible()
    host.view.setNeedsLayout()
    host.view.layoutIfNeeded()
    RunLoop.main.run(until: Date().addingTimeInterval(0.05))
    XCTAssertGreaterThan(measuredWidth, 0)
    let content = UIHostingController(rootView:
      ToastContentView(toast: toast, isMultiline: false, onAction: {}))
    let natural = content.sizeThatFits(in: CGSize(width: 1000, height: 1000))
    let measured = content.sizeThatFits(in: CGSize(width: measuredWidth, height: 1000))
    XCTAssertEqual(measured.height, natural.height, accuracy: 1,
      "The probe must reserve enough width for the avatar and both text lines")
    window.isHidden = true
  }
}
