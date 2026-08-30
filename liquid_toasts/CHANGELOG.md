## 0.7.0

* **Global line limits** — `LiquidToastsConfig.maxLines` and
  `titleMaxLines` apply to every toast that omits a per-toast value, including
  raw `Toast` values and `toast.promise` phases. Existing semantic defaults are
  unchanged when the global values are null.
* **Custom safe area** — `LiquidToastsConfig.safeArea` reserves app-owned
  screen space in Flutter logical pixels. SwiftUI and Compose take the larger
  of each custom edge and the real device safe-area inset, so toasts avoid app
  headers, floating controls, and bottom navigation on both platforms.

## 0.6.0

**Shake in place & smarter overflow.** Two native refinements to how the stack
behaves. The Dart API and wire protocol are unchanged.

* **Shake on unchanged re-show** — re-showing a toast that shares a `groupKey`
  with a still-visible one now **shakes it horizontally in place** instead of
  replaying the exit + enter animation, when the title and message are
  unchanged (e.g. tapping "Copy" again while the confirmation is still up). A
  re-show that *changes* the text still morphs/replaces as before. Respects
  Reduce Motion / disabled animations. iOS (SwiftUI `GeometryEffect`) and
  Android (Compose `graphicsLayer`).
* **Persistent toasts survive overflow** — the per-position `maxVisible` cap now
  evicts only **auto-dismiss** toasts. Persistent toasts (`duration:
  Duration.zero`) and `promise`/`loading` spinners have no auto-dismiss deadline
  and are caller- or promise-owned, so they are no longer force-dismissed when a
  burst of new toasts exceeds the cap — a position may exceed `maxVisible` while
  it is full of them. They leave only when you (or the user) dismiss them.

## 0.5.0

**Custom surface color.** New `ToastStyleOverride.background` colors the toast
surface, with automatic contrast-aware text.

* **`background`** — a `ToastColor` for the surface. On iOS 26+ it tints the
  Liquid Glass (a translucent wash over the live refraction — pass a reduced
  alpha for subtlety); on the iOS 17–25 frosted tier, under Reduce Transparency,
  and on Android it fills the opaque surface. Null keeps the neutral adaptive
  default. `tint` now strictly means the *accent* (icon/spinner/ring) and never
  touches the surface.
* **Automatic foreground** — when `background` is set and `foreground` is left
  null, a readable text color (near-black or near-white, chosen per light/dark
  by WCAG contrast) is derived automatically. An explicit `foreground` always
  wins. Title renders at full strength, the message at 85% — hierarchy by weight
  + opacity, unchanged. A neutral (`semantic: none`) icon adopts the same
  on-color; a semantic toast keeps its role-colored glyph.
* **`ToastColor.hex()`** — construct colors from hex strings
  (`ToastColor.hex('#b0afb0')`, `ToastColor.hex('#2196F3', dark: '#0D47A1')`);
  `#RRGGBB` and `#AARRGGBB` (with or without `#`/`0x`) are accepted.
* Additive wire change (new optional `background` key); no protocol bump.

## 0.4.0

**Android support.** The plugin now renders natively on Android too, with full
parity to the iOS behavior. No API changes — the entire Dart surface, wire
protocol, and semantics are shared across platforms.

* **Native Jetpack Compose renderer** — toasts are drawn on a Compose overlay
  installed into the activity's decor view, above the Flutter UI, with the same
  pass-through hit-testing (touches fall through to your app except where a
  toast sits). No `BuildContext`, no per-app setup or Gradle changes.
* **Behavior parity with iOS** — positions, per-position vertical stacking,
  semantics, one action button (incl. async `loadingOnPress`), `toast.promise`
  loading→success/error morphs, linear + circular progress, replace-by-`groupKey`,
  tap- and swipe-to-dismiss, and **wall-clock auto-dismiss that survives
  backgrounding** all behave identically. Same wire acks, dismiss reasons, and
  lifecycle events. A hot restart flushes stale toasts, as on iOS.
* **Opaque surface** — Android renders an **opaque** adaptive surface
  (dark `#242424` / light `#FAFAFA`) with the same hairline stroke, drop shadow,
  spring entrance, and fade-out — deliberately not a blur/glass material, so a
  toast always reads as a raised card over busy content. The show ack reports
  `glassMode: "opaque"`.
* **Icons** — SF Symbol names are mapped to matching Material glyphs (the four
  semantic defaults, all example-app symbols, plus common extras), falling back
  to the semantic default glyph for unknown names. Icons render statically —
  animated SF Symbol effects remain iOS-only. Leading images/avatars decode off
  the main thread, as on iOS. Haptics map to the Android vibrator.
* **Requirements** — Android **7.0+** (API 24), compiled against SDK 36 with
  Kotlin 2.3.20 / Jetpack Compose.

## 0.3.0

A new primary API — the global `toast` object — plus an internal engine
rewrite. The old `LiquidToasts` facade keeps working as deprecated delegates
(removal planned for 1.0).

* **New `toast` API** — a callable, Sonner-style entry point whose `show`
  methods return the `ToastHandle` **synchronously** (no `await`):
  `toast('Hi')`, `toast.success('Saved')`, `toast.loading('Working…')`,
  `toast.raw(Toast(...))`. If the name collides with your code,
  `hide toast` and use `Toaster.instance`.
* **`toast.promise`** — replaces `showLoading` + `LoadingToast`:
  `toast.promise(future, loading: 'Signing in…', success: (u) => 'Hi ${u.name}',
  error: 'Failed')`. Specs accept a `String`, a `Toast`, or a builder; invalid
  specs throw `ArgumentError` at the call site. Still returns the future's
  value / rethrows its error.
* **Patch-style handle updates** — `handle.update(progress: 0.6)` changes only
  what you pass; rapid patches compose in order. Full replacement moved to
  `handle.replace(Toast)`.
* **BREAKING** — `ToastHandle.update(Toast)` is now `ToastHandle.replace(Toast)`;
  `ToastHandle.completer` is private; `Toast.position` and
  `LiquidToastsConfig.defaultDuration` are nullable (null = app/semantic
  default, resolved at show time).
* **Behavior** — error toasts now default to 4 s everywhere (previously the
  config default of 3 s applied via `LiquidToasts.error`); an explicit
  `duration: null` on the new API means persistent instead of being silently
  coerced to the config default; `toast.promise` success toasts show for the
  semantic default (3 s) instead of `LoadingToast`'s 2 s.
* **Deprecated** — every `LiquidToasts` member and `LoadingToast`, each with a
  migration hint. They delegate to the same engine, so old and new call sites
  can be mixed during migration.
* **Fixes** — `dismissAll` can no longer orphan a native toast whose `show`
  was still in flight (it is chased down and dismissed); an `update` that
  swaps a toast's action now reliably supersedes an in-flight
  `loadingOnPress` completion, even when the same `ToastAction` instance is
  reused; toasts without a leading image no longer touch the image pipeline
  on the show path.
* **iOS performance** (internal; no wire changes, visuals verified
  frame-identical against pre-refactor recordings) — rendering is isolated
  per toast: updating one toast no longer re-renders every visible toast, and
  dragging or animating no longer invalidates the whole overlay on every
  frame (hit-test frames and auto-dismiss timer state no longer publish
  through SwiftUI). Leading images are decoded — and large sources
  downsampled — off the main thread instead of synchronously inside the
  platform-channel call, with the avatar slot reserved up front so nothing
  shifts when the pixels land.

## 0.2.0

Richer toast content. No breaking changes — every addition is opt-in with a
default that reproduces the previous rendering.

* **Leading image / avatar** — `Toast.leadingImage` takes any Flutter
  `ImageProvider` (`AssetImage` / `NetworkImage` / `MemoryImage` / …). It's
  resolved to bytes off the Flutter image pipeline and rendered as a circular
  avatar in the leading slot, in place of the SF Symbol.
* **Title wrapping** — `Toast.titleMaxLines` (default 1) lets a long title wrap
  instead of truncating to one line.
* **Async action buttons** — `ToastAction.onPressed` is now
  `FutureOr<void> Function()`, and `ToastAction.loadingOnPress` replaces the
  button label with a spinner until the future resolves, then dismisses.
* **Centered text** — a compact, text-only toast (no leading glyph, no trailing
  action, not the full-width layout) now centers its text; everything else stays
  left-aligned.

## 0.1.0

iOS multiline layout, progress styles, and interaction polish. No breaking
changes — everything below is additive (`progressStyle` defaults to `.linear`,
which reproduces the previous rendering).

* **Multiline toasts** — a message that wraps past one line (set `maxLines >= 2`)
  now renders as a wider, left-aligned rounded rectangle (≈4/5 width, inset like
  an iOS notification, capped on large screens) instead of a tall centered
  capsule. Single-line toasts keep the hugging capsule. Note `Toast.error` /
  `Toast.warning` default to `maxLines: 2`, so their long messages adopt this.
* **Progress styles** — new `ToastProgressStyle { linear, circular }` on
  `Toast.progressStyle`. `linear` is the bar under the text (now fills the width
  on multiline toasts); `circular` shows a determinate ring in the leading slot.
* **Pause on interaction** — a toast's auto-dismiss countdown now pauses while
  you touch / hold / drag it, and resumes on release.
* **Animated morphs** — updating a toast across the single-line ↔ multiline
  boundary (e.g. an upload's progress → "done") animates its width and corners
  in place instead of snapping.
* Tooling: `tool/record_demo.sh` + `example/lib/demo_harness.dart` for recording
  high-quality 60fps demo clips on the iOS simulator.

## 0.0.1

Initial release — iOS support.

* SwiftUI-native toasts rendered on a same-window overlay (no `BuildContext`).
* Adaptive Liquid Glass (iOS 26+) with a frosted `.ultraThinMaterial` fallback
  (iOS 17–25) and an opaque surface under Reduce Transparency.
* Dynamic Island origin animation for top-center toasts (public APIs only);
  slide-in fallback elsewhere and on notch / home-button devices.
* Loading toasts tied to a `Future` — spinner → success/error — that return the
  value / rethrow the error to the caller.
* Per-position vertical stacking (max 5; overflow fades/blurs out in place),
  semantic styles (success/error/warning/info), SF Symbol icons with
  customizable adaptive colors and optional animated symbol effects (bounce,
  pulse, wiggle, rotate, breathe, variableColor, iOS-26 drawOn), and a single
  role-colored action button.
* Production extras: tap-to-dismiss, replace-by-key, determinate progress,
  haptics, accessibility (VoiceOver + Reduce Motion), app-wide defaults, and
  active-toast introspection.
* Requires iOS 17.0+ and Flutter 3.27+. Android is not yet implemented.
