# LiquidToasts

Premium, natively-drawn toasts for SwiftUI and UIKit apps — a springy slide-in
from the nearest edge, per-position vertical stacking, adaptive Liquid Glass,
and async loading toasts. No view controller, no window, no environment
plumbing: the overlay installs itself into your key window on first use and
lets touches through everywhere a toast isn't.

Requires **iOS 17+**. Real `glassEffect` Liquid Glass activates on iOS 26+, a
frosted `.ultraThinMaterial` renders on 17–25, and an opaque surface under
*Reduce Transparency*.

> This package is also the iOS renderer behind the
> [`liquid_toasts` Flutter plugin](../liquid_toasts/README.md) — they share one
> stack, so a hybrid app can show toasts from either side.

## Install

Xcode: **File → Add Package Dependencies…** →
`https://github.com/SimplifyJobs/liquid-toasts.git`, *Up to Next Major*, then
add the **LiquidToasts** library to your target.

`Package.swift`:

```swift
dependencies: [
  .package(url: "https://github.com/SimplifyJobs/liquid-toasts.git", from: "0.8.0")
],
targets: [
  .target(name: "App", dependencies: [
    .product(name: "LiquidToasts", package: "liquid-toasts")
  ])
]
```

## Quick start

Everything on `LiquidToast` is main-actor isolated.

```swift
import LiquidToasts

LiquidToast.show("Saved")                       // plain
LiquidToast.success("Profile updated")          // green check, success haptic, 3s
LiquidToast.error("Could not connect")          // red glyph, 2 lines, 4s
LiquidToast.warning("Low storage")
LiquidToast.info("3 updates available")
```

Every variant returns a `LiquidToastHandle` (discardable) and takes the same
options — `title:`, `icon:` (an SF Symbol name), `image: UIImage`, `style:`,
`position:`, `duration:`, `action:`, `onTap:`, `tapToDismiss:`, `groupKey:`,
`progress:`, `progressStyle:`, `haptic:`, `accessibilityLabel:`, `maxLines:`,
`titleMaxLines:`.

```swift
LiquidToast.show(
  "Copied link",
  icon: "link",
  position: .bottomCenter,
  duration: .seconds(2))
```

`duration` is a `ToastDuration`: `.default` (the configured or per-semantic
value), `.seconds(_:)`, `.milliseconds(_:)`, or `.persistent`.

Positions — each its own vertical stack: `.topCenter` `.topLeading`
`.topTrailing` `.center` `.bottomCenter` `.bottomLeading` `.bottomTrailing`.

## Action button

The handler never reaches the renderer; the facade keeps it keyed by toast id.

```swift
LiquidToast.show(
  "Message deleted",
  duration: .seconds(5),
  action: LiquidToastAction(label: "Undo", role: .primary) {
    await inbox.restoreLastDeleted()
  })
```

`role` is `.primary` `.secondary` `.destructive` `.success` `.warning`
`.neutral`. Set `loadingOnPress: true` to swap the label for a spinner and hold
the toast up until the handler returns; `dismissOnPress: false` keeps it on
screen afterwards.

## Live handle

```swift
let upload = LiquidToast.loading("Uploading…", progress: 0)   // persistent spinner
upload.update(progress: 0.6)
upload.update(
  message: "Uploaded",
  semantic: .success,
  duration: .seconds(2),
  loading: false)

upload.dismiss()                                              // explicit removal
upload.onDismissed { reason in print("gone:", reason) }       // ToastDismissReason
let reason = await upload.dismissal                           // or await the reason
```

`update(...)` is patch-style: only the fields you pass change, everything else
is kept and the toast morphs in place. It returns `false` when the toast is
already gone (an expected race, not an error). `isShowing` / `isDismissed`
report the current state.

## Wrap async work

```swift
let user = try await LiquidToast.promise(
  loading: "Signing in…",
  success: { "Welcome back, \($0.firstName)!" },
  error: { _ in "Sign-in failed" }
) {
  try await api.signIn(email, password)
}
```

**It returns your value and rethrows your error** — the toast is best-effort
and never swallows the outcome. Omit `error:` to fall back to
`LiquidToast.errorMessageResolver` (a global hook mapping an error to a
user-safe string), then to `localizedDescription`.

## Styling

```swift
LiquidToast.show(
  "Saved to Library",
  style: ToastStyleModel(
    tint: ToastColor(light: .indigo, dark: .indigo),
    background: ToastColor(light: .white, dark: .black),
    symbolEffect: .bounce))
```

`ToastColor(light:dark:)` resolves against the current color scheme natively.
`tint` colors the accent (icon, spinner, progress); `background` tints the
glass on iOS 26+ and fills the surface below it; `foreground` overrides the
otherwise auto-derived text color; `iconColor`, `glass` and `cornerRadius`
round it out. `symbolEffect` animates the SF Symbol (`.bounce`, `.pulse`,
`.wiggle`, `.rotate`, `.breathe`, `.variableColor`, `.drawOn`).

## App-wide defaults

```swift
LiquidToast.configure(LiquidToastConfiguration(
  defaultPosition: .topCenter,
  defaultDuration: 3,
  maxLines: 3,
  safeArea: ToastSafeAreaInsets(top: 96, bottom: 72),
  maxVisible: 3))

LiquidToast.prepare()   // optional: install the overlay at launch so the very
                        // first toast gets its entrance transition
```

Values a call site sets explicitly always win. `safeArea` is a *minimum* inset
on top of the real device safe area (the larger value wins at each edge), so
you can reserve room for a header or bottom bar without double-counting.

## Managing the stack

```swift
LiquidToast.dismiss(id)          // prefer handle.dismiss()
LiquidToast.dismissAll()
LiquidToast.activeIds            // [String]
LiquidToast.activeCount          // Int
LiquidToast.geometrySnapshot()   // safe area / screen / cutout / glass mode
```

`ToastManager` and `ToastOverlayHost` underneath are public too, but low-level:
they deal in opaque ids and hold no callbacks. `LiquidToast` is the layer to
reach for.
