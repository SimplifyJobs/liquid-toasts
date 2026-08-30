# liquid_toasts

Premium, **natively-rendered** toasts for Flutter — drawn above your app in
**SwiftUI on iOS** and **Jetpack Compose on Android**, with a springy slide-in
entrance, per-position vertical stacking, and async **loading** toasts. One
platform-neutral Dart API; no `BuildContext` required.

## Showcase

<table>
  <tr>
    <td width="50%" align="center">
      <video src="https://github.com/user-attachments/assets/35c34736-37f6-478c-911f-7d94a9234b13" width="300" muted controls></video><br/>
      <sub><b>Stacking</b> — staggered in and out</sub>
    </td>
    <td width="50%" align="center">
      <video src="https://github.com/user-attachments/assets/3af9f57d-c4e9-4e44-9113-74d56a5e7e14" width="300" muted controls></video><br/>
      <sub><b>Animated icons</b> — SF Symbol effects</sub>
    </td>
  </tr>
  <tr>
    <td width="50%" align="center">
      <video src="https://github.com/user-attachments/assets/4929a654-f2e2-437a-aa40-95209c7d7344" width="300" muted controls></video><br/>
      <sub><b>Progress</b> — determinate upload</sub>
    </td>
    <td width="50%" align="center">
      <video src="https://github.com/user-attachments/assets/fad24d65-6794-4289-a440-60576e57d40d" width="300" muted controls></video><br/>
      <sub><b>Action button</b> — inline Undo</sub>
    </td>
  </tr>
</table>

## Highlights

- **Native rendering** — toasts are drawn on a native overlay above your
  Flutter UI (SwiftUI on iOS, Jetpack Compose on Android), so they float over
  everything and need no `BuildContext`. The whole Dart API is identical across
  platforms.
- **Adaptive surface** — on iOS, real `glassEffect` Liquid Glass on iOS 26+, a
  frosted `.ultraThinMaterial` fallback on iOS 17–25, and an opaque surface
  under *Reduce Transparency*. On Android, an opaque adaptive surface
  (dark/light) with the same hairline stroke and drop shadow.
- **Springy entrance** — toasts slide in from the nearest edge (down from the
  top, up from the bottom) with a fade + scale, and fade + blur away in place.
- **Loading lifecycle** — wrap a `Future`; show a spinner, then morph to
  success/error. The call **returns your value / rethrows your error**, so your
  app owns the outcome.
- **Vertical stacking** — each position is its own list (up to 5 toasts);
  newest pushes the rest along, and overflow scales + fades + blurs away in
  place.
- **Semantic styles** — `success` / `error` / `warning` / `info`, each
  overridable. Icons are named as SF Symbols; on Android the same names are
  mapped to matching Material glyphs (falling back to the semantic default for
  unknown names). Customizable (adaptive) icon colors on both platforms.
- **Animated icons** — opt into an SF Symbol effect (`bounce`, `pulse`,
  `wiggle`, `rotate`, `breathe`, `variableColor`, or iOS-26 `drawOn`) per toast
  (iOS only; the glyph renders statically on Android).
- **One action button** — fully rounded, color derived from a semantic role.
- **Production extras** — tap-to-dismiss, replace-by-key, determinate progress,
  haptics, accessibility (VoiceOver + Reduce Motion), app-wide defaults, and
  `activeCount` / `activeIds` introspection.

## Requirements

- iOS **17.0+** (Liquid Glass auto-activates on iOS 26+; frosted fallback below).
- Android **7.0+** (API 24). Rendered natively in Jetpack Compose; no extra
  setup or Gradle changes needed in a standard Flutter app.
- Flutter **3.27+**.

## Platform support

The Dart API, wire protocol, and behavior are identical on both platforms —
positions, stacking, semantics, actions (incl. async), `promise` morphs,
progress, replace-by-key, tap/swipe-to-dismiss, wall-clock auto-dismiss (which
survives backgrounding), haptics, and accessibility all work the same. Only the
native surface differs:

| | iOS | Android |
|---|---|---|
| Renderer | SwiftUI overlay (same window) | Jetpack Compose overlay (decor view) |
| Surface | Liquid Glass (26+) / `.ultraThinMaterial` (17–25) / opaque | Opaque adaptive surface (dark/light) |
| Icons | SF Symbols + animated symbol effects | SF Symbol names mapped to Material glyphs (static) |
| Dynamic Island origin | Yes (top-center) | — (slide-in) |
| Min version | iOS 17.0 | Android 7.0 (API 24) |

Android renders an **opaque** surface rather than a blur/glass material — same
hairline stroke, drop shadow, spring entrance, and fade-out — so a toast reads
as a raised card that never becomes unreadable over busy content.

## Install

The plugin lives in the [`liquid-toasts`](https://github.com/SimplifyJobs/liquid-toasts)
monorepo alongside the standalone SwiftUI package it renders with, so it is
installed as a git dependency with a `path`:

```yaml
dependencies:
  liquid_toasts:
    git:
      url: https://github.com/SimplifyJobs/liquid-toasts.git
      ref: v0.7.0
      path: liquid_toasts
```

> **Required, once per machine:** the iOS side is Swift Package Manager only —
> there is no podspec.
>
> ```bash
> flutter config --enable-swift-package-manager
> ```
>
> Without it, an iOS build fails with a missing-podspec error. Android needs no
> setup.

## Usage

```dart
import 'package:liquid_toasts/liquid_toasts.dart';

// Semantic one-liners — fire and forget, no await, no BuildContext
toast.success('Saved to favorites');
toast.error('Could not connect');
toast.warning('Low storage');
toast.info('3 updates available');
toast('Plain message'); // the object is callable
```

### Action button

```dart
toast.warning(
  'Low storage',
  duration: null, // persistent until tapped/dismissed
  action: ToastAction(
    label: 'Manage',
    role: ToastActionRole.primary,
    onPressed: openStorageSettings,
  ),
);
```

### Wrap a future (the call returns your result)

```dart
final user = await toast.promise(
  api.signIn(email, password),
  loading: 'Signing in…',
  success: (u) => 'Welcome back, ${u.firstName}!',
  error: 'Sign-in failed',
);
// `user` is your value; on failure the call rethrows so your try/catch fires.
```

`loading` / `success` / `error` each take a `String`, a full `Toast`, or a
builder (`(value) => …` / `(error) => …`).

### Persistent toast + live handle

```dart
final t = toast.loading('Connecting…');       // handle returned synchronously
await Future.delayed(const Duration(seconds: 2));
t.update(loading: false, message: 'Connected', semantic: ToastSemantic.success);
t.dismiss();
final reason = await t.onDismissed;           // always completes
```

`update` patches only the fields you pass (rapid patches compose, in order);
`replace(Toast(...))` swaps the content wholesale.

### Positioning, replace-by-key, progress

```dart
// Bottom toast
toast.show('Copied link', icon: 'link', position: ToastPosition.bottomCenter);

// Replace-or-update instead of stacking duplicates
toast.info('Reconnecting…', groupKey: 'net', duration: null);

// Determinate progress via patch updates
final t = toast.show('Uploading…', duration: null, progress: 0);
t.update(progress: 0.6);
t.update(progress: 1.0, message: 'Uploaded', duration: const Duration(seconds: 2));
```

### Custom colors

```dart
// Color the surface. iOS 26+ tints the glass (pass reduced alpha for subtlety);
// elsewhere (iOS 17–25 frosted, Reduce Transparency, Android) it fills the surface.
toast.show(
  'Saved to Library',
  style: const ToastStyleOverride(background: ToastColor(Color(0xFF1E1E2E))),
);

// Hex strings work too. Leave `foreground` null and a readable text color
// (near-black/near-white, per light/dark) is derived automatically by contrast.
toast.show(
  'Copied',
  style: ToastStyleOverride(background: ToastColor.hex('#b0afb0')),
);
```

`tint` colors the accent (icon / spinner / progress ring); `background` colors
the surface; `foreground` overrides the (otherwise auto-derived) text color.
Each is a `ToastColor(light, dark:)` and resolves adaptively — no `BuildContext`.

### App-wide defaults

```dart
toast.setDefaults(const LiquidToastsConfig(
  defaultPosition: ToastPosition.topCenter,
  maxLines: 3,          // messages (per-toast maxLines still wins)
  titleMaxLines: 2,     // titles (per-toast titleMaxLines still wins)
  safeArea: EdgeInsets.only(top: 96, bottom: 72),
  maxVisible: 3,
));
```

`defaultDuration` left null keeps the per-semantic defaults
(success/info/warning 3 s, error 4 s).

`safeArea` is a minimum inset in logical pixels. The native overlays always
respect the real device safe area too, taking the larger value at each edge, so
you can reserve space for app headers, floating controls, or bottom navigation
without double-counting the status bar or home indicator.

> **Name collision?** `import 'package:liquid_toasts/liquid_toasts.dart' hide
> toast;` and use `Toaster.instance`.

## API at a glance

| Type | Purpose |
|---|---|
| `toast` (a `Toaster`) | The primary API: callable `show` · `success/error/warning/info/loading` · `raw(Toast)` · `promise` · `dismiss/dismissAll` · `setDefaults` · `queryGeometry` · `activeCount/activeIds` — all shows return the handle synchronously |
| `Toast` | Immutable content (message, title, SF Symbol icon, semantic, style, position, duration, action, progress, haptic, …) with named constructors and `copyWith` |
| `ToastAction` | Single action button (`label`, `onPressed`, `role`, `color`) |
| `ToastHandle` | Live controller: patch-style `update(...)`, `replace(Toast)`, `dismiss`, `onDismissed` |
| `ToastStyleOverride` / `ToastColor` | Per-toast `background` (surface) / `tint` (accent) / `foreground` (text, auto-derived from background) / `iconColor` / `glass` / `cornerRadius` overrides (adaptive light/dark; `ToastColor.hex(...)` for hex) |
| `LiquidToastsConfig` | App-wide position/duration, message/title line limits, minimum safe area, and stack limits |
| `LiquidToasts` / `LoadingToast` | **Deprecated** legacy facade — working delegates until 1.0 |

## Migrating from `LiquidToasts`

The old static facade still works (with deprecation hints) and shares the same
engine, so you can migrate incrementally:

| Before | After |
|---|---|
| `await LiquidToasts.success('Hi')` | `toast.success('Hi')` (no await) |
| `await LiquidToasts.show(Toast(...))` | `toast.raw(Toast(...))` |
| `LiquidToasts.showLoading(f, config: LoadingToast(...))` | `toast.promise(f, loading:, success:, error:)` |
| `handle.update(Toast(...))` | `handle.replace(Toast(...))` — or patch: `handle.update(progress: 0.6)` |
| `LiquidToasts.dismissAll()` | `toast.dismissAll()` |
| `LiquidToasts.setDefaults(...)` | `toast.setDefaults(...)` |

## Using it from native iOS

The SwiftUI renderer is its own package — `LiquidToasts` — published from the
same repo, with a `LiquidToast.show(…)` facade mirroring this Dart API. A
hybrid app can use both: they share one stack. See
[`liquid-toasts-swift/README.md`](../liquid-toasts-swift/README.md).

## Notes for contributors

The bundled `example/` depends on the plugin via a path dependency (`path: ../`)
and builds it in SwiftPM mode, where the plugin's bridge package pulls the
SwiftUI core from the repo-root `Package.swift`. Run `flutter analyze` and
`flutter test` from this directory; run the app from `example/`.

## License

See [LICENSE](../LICENSE).
