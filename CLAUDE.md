# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A **monorepo shipping two packages** built from one SwiftUI implementation:

- **`LiquidToasts`** — a standalone SwiftUI package for native iOS apps.
  Sources at `liquid-toasts-swift/Sources/LiquidToasts/`; its manifest is the
  **repo-root `Package.swift`** (SwiftPM only resolves a git URL whose repo
  root holds a manifest, so the root one is thin and points at that folder via
  `path:`). Native entry point: `LiquidToast.show(…)`.
- **`liquid_toasts`** (`liquid_toasts/`) — the Flutter **plugin**: a
  context-free Dart API (`toast.success('hi')`) over a native overlay. On iOS
  it is a *bridge only* — channels and wire decoding — and gets every pixel
  from the `LiquidToasts` package above, referenced by relative path
  (`../../..`). Android is implemented inside the plugin in Jetpack Compose.

Both render premium, natively-drawn toasts on an overlay above the app —
springy entrance, per-position vertical stacking, async loading toasts — with
**no `BuildContext` / view controller required**. iOS uses adaptive Liquid
Glass; Android an opaque adaptive surface (no blur/glass). The Dart API and
wire protocol are platform-neutral, and both facades share one native stack.

`docs/monorepo-plan.md` records why the repo is shaped this way.

## Commands

Run Dart commands from `liquid_toasts/`; run the app from
`liquid_toasts/example/`.

```bash
cd liquid_toasts
flutter analyze                         # lint (flutter_lints, see analysis_options.yaml)
flutter test                            # all Dart unit tests
flutter test test/toaster_test.dart                          # one file
flutter test --plain-name 'show serializes the toast'        # one test by name

cd example && flutter run               # run the demo app (needs an iOS device/sim)
cd example && flutter run -t lib/showcase.dart   # run the README recording harness
```

Native Swift code is built by the Flutter/Xcode toolchain when you run the
example; there is no standalone `swift build` (the package is iOS-only — use
`xcodebuild -scheme liquid-toasts -destination 'generic/platform=iOS Simulator'`
against the root package if you want to compile the core alone).

### SwiftPM-only

There is no podspec. The example — and every consumer — must run with Flutter's
SwiftPM mode enabled:

```bash
flutter config --enable-swift-package-manager
```

A CocoaPods-mode build fails with a missing-podspec error. The example depends
on the plugin via `path: ../`, and the plugin's bridge package resolves the
core through the repo-root manifest, so a plain checkout builds with no extra
setup.

## CI / releases

`.github/workflows/ci.yml` runs on every pull request and on pushes to `main`:

| Job | Runner | What |
| --- | --- | --- |
| `dart` | ubuntu | `flutter analyze` + `flutter test` in `liquid_toasts/` |
| `swift` | macOS | `xcodebuild build -scheme liquid-toasts -destination 'generic/platform=iOS Simulator'` against the root package (the auto-generated scheme is named after the package, not the product) |
| `example` | macOS | `flutter build ios --no-codesign --debug`, after `flutter config --enable-swift-package-manager` (CocoaPods mode hard-fails) |
| `android` | ubuntu | `flutter build apk --debug`, then `./gradlew :liquid_toasts:testDebugUnitTest` from `liquid_toasts/example/android` — the APK build is what generates the Gradle wrapper and `local.properties` those tests need |

`.github/workflows/release.yml` fires on a `v*` tag: it reuses ci.yml wholesale
(via `workflow_call`), then creates the GitHub Release.

**To release:** add the section to `liquid_toasts/CHANGELOG.md`, bump `version:`
in `liquid_toasts/pubspec.yaml` to match, update the install snippets in the
three READMEs, and push a `vX.Y.Z` tag. The workflow fails loudly before
publishing anything if the tag and the pubspec version disagree; the release
body is that CHANGELOG section (headers carry no `v`) plus an install block
pinned to the tag. Both packages ship from that one tag and SwiftPM and pub both
resolve straight from it, so nothing is attached to the release.

## Architecture

```
Package.swift                          # root manifest for the core package
liquid-toasts-swift/Sources/LiquidToasts/   # the SwiftUI core (Flutter-free)
liquid_toasts/                         # the Flutter plugin
  lib/  test/  android/  example/
  ios/liquid_toasts/                   # bridge-only Swift package
tool/  docs/  assets/                  # repo-level
```

The plugin is a **two-layer bridge**: a context-free Dart engine that owns
caller-facing state, and a SwiftUI overlay on iOS that owns all rendering and
the actual toast stack. They communicate over a method channel (Dart→native
commands) and an event channel (native→Dart lifecycle events).

### Dart side (`liquid_toasts/lib/`)

- `ToastEngine` (`lib/src/toast_engine.dart`, internal singleton) — owns ALL
  state: the registry mapping toast id → `ToastRegistration` (dismissal
  `Completer`, action callback + `activeActionId`, `onTap`, `lastToast`,
  generation counter, per-toast op chain), the event subscription, the memoized
  handshake, and the config. Every platform operation for a toast runs on its
  registration's **FIFO op chain**, which is what lets `show` return a handle
  synchronously — an `update`/`dismiss` issued before the show acks just queues
  behind it. Op errors never escape to fire-and-forget callers (a failed show
  completes the handle `channelLost`). `dismissAll` chases in-flight shows with
  an idempotent per-id dismiss so no native toast is orphaned.
  **All user callbacks (action/tap) live here, never cross the wire** — native
  only echoes back ids, so a stale tap after an `update` swapped the action is
  dropped by comparing `activeActionId`; a replace/patch bumps the registration
  `generation`, which supersedes any in-flight `loadingOnPress` completion.
- `Toaster` / `toast` (`lib/src/toaster.dart`, exported) — the public API: a
  const callable object (`toast('hi')`, `toast.success(...)`,
  `toast.promise(...)`, `toast.raw(Toast)`), all delegating to the engine.
  Convenience toasts are constructed in exactly one place (`_semanticShow`),
  where omitted-vs-explicit-null duration is resolved
  (explicit > `LiquidToastsConfig.defaultDuration` > `SemanticDefaults`).
  A null `Toast.position` resolves to the config default in the engine.
- `lib/liquid_toasts.dart` — the package barrel: the exports plus the top-level
  `toast` constant. (The legacy `LiquidToasts` static facade lived here and was
  removed in 0.8.0.)
- `LiquidToastsPlatform` (`lib/liquid_toasts_platform_interface.dart`) — the
  `PlatformInterface` the engine talks to; swap `.instance` with a fake in tests.
- `MethodChannelLiquidToasts` (`lib/liquid_toasts_method_channel.dart`) — the iOS
  impl. Every command is wrapped in an `_envelope` carrying `protocolVersion`
  (currently `1`); bump it on incompatible wire changes.
- `lib/src/` — the wire models: `toast.dart` (`Toast` + `copyWith` + `toMap`;
  all constructors funnel through a canonical private `_raw` ctor),
  `semantic_defaults.dart` (the ONLY home of per-semantic duration/maxLines/
  haptic defaults), `toast_action.dart`, `toast_handle.dart` (patch-style
  `update(...)` + `replace(Toast)`),
  `toast_event.dart` (inbound events + `ToastDismissReason`), `toast_style.dart`,
  `toast_position.dart`, `liquid_toasts_config.dart`, `ids.dart` (id minting).

### iOS side — two SwiftPM modules

| | Path | Contents |
|---|---|---|
| **core** (`LiquidToasts`) | `liquid-toasts-swift/Sources/LiquidToasts/` | the renderer, the stack, the scheduler and the `LiquidToast` facade — everything except the three bridge files; **no `import Flutter` anywhere** |
| **bridge** (`liquid_toasts`) | `liquid_toasts/ios/liquid_toasts/Sources/liquid_toasts/` | `LiquidToastsPlugin.swift`, `WireModels.swift`, `WireDecoding.swift` — the ONLY Flutter-aware code, and the ONLY place the wire format lives |

The bridge files `import LiquidToasts` and may use nothing but the core's
`public` API — if a bridge change needs a new symbol, widen access in the core
deliberately rather than reaching in. (`WireDecoding.swift` needs no import: it
is pure `Dictionary` helpers.) Native apps get `LiquidToast`, a static facade
mirroring the Dart `toast` API; `ToastManager` under it is public too but
documented as low-level. Everything else stays `internal`.

Each target ships its own `PrivacyInfo.xcprivacy` (both declare no collection
and no required-reason APIs) as a `.process` resource.

**Bridge:**

- `LiquidToastsPlugin.swift` — the `FlutterPlugin`/`FlutterStreamHandler`. Decodes
  channel args into `ToastModel`s and drives the manager. Flutter calls channel
  handlers on the main thread, so it uses `MainActor.assumeIsolated` and touches
  UI directly with no actor hop. Owns the **only** mapping from the typed
  `ToastEventPayload` back to the wire dictionaries (`wireEvent`), and
  deliberately drops `.flushed` — a flush is silent by contract.
- `WireModels.swift` — the `init?(wire:)`/`init?(arguments:)` decoders that turn
  channel payloads into the core models (cross-module extensions on `public`
  types, so they need `import LiquidToasts`). The one `FlutterStandardTypedData`
  check lives here.
- `WireDecoding.swift` — `[String: Any]` decode helpers (NSNumber-aware).

**Core:**

- `LiquidToast.swift` — the native facade: `show/success/error/warning/info/
  loading`, `promise`, `configure`, `dismiss(All)`. Thin wrappers over one
  private `present(...)` funnel, mirroring `Toaster._semanticShow`.
- `LiquidToastCenter.swift` — the facade's engine, mirroring `ToastEngine`:
  the native registry (handle, action/tap callbacks, `activeActionId`,
  `generation`), native id minting (`lt_native_<uuid>`, which can never collide
  with Dart's `lt_<sessionPrefix>_<nnnn>`), and the event router. No op chain
  and no handshake — `ToastManager` is a direct call away.
- `LiquidToastHandle.swift` / `LiquidToastAction.swift` /
  `LiquidToastConfiguration.swift` — the facade's value types (patch-style
  `update`, `onDismissed`/`dismissal`, the action + its callback, app-wide
  defaults and the `ToastDuration` "omitted" sentinel).
- `SemanticDefaults.swift` — **LOCKSTEP with
  `liquid_toasts/lib/src/semantic_defaults.dart`**: the per-semantic duration /
  line cap / appear-haptic table the native facade uses. Both files carry the
  cross-reference; change both or neither.
- `ToastEvents.swift` — `ToastDismissReason` (raw values = wire strings),
  the typed `ToastEventPayload` and the listener token.
- `ToastOverlayHost.swift` — singleton that installs a transparent
  `PassthroughHostView` + `UIHostingController` into the **same window** as
  Flutter content (so Liquid Glass can sample the live app behind it). The host
  hit-tests against `manager.frames` so touches pass through to Flutter except
  where a real toast sits. Installed eagerly at plugin registration so the first
  toast gets its entrance transition.
- `ToastManager.swift` — `@MainActor ObservableObject`, the single source of
  truth for the stack. Owns the queue, replace-by-`groupKey`, per-position
  `maxVisible` enforcement, exactly-once teardown, and **fans typed lifecycle
  events out to every listener** (`addEventListener` → `ToastEventToken`) —
  the bridge and the native facade subscribe independently and each ignores
  ids it doesn't own. **Publish surface is deliberately minimal**: `toasts` is the
  one SwiftUI input (runtime flags like `isActionBusy` live on the models);
  `frames` is intentionally NOT `@Published` (only the host's hit-test reads
  it, imperatively — publishing it would invalidate the whole container on
  every animation frame of a drag or spring); `stackGeneration` (plain var,
  bumped only when the id set changes) is the container's animation token.
- `DeadlineScheduler.swift` — owns ALL auto-dismiss timing: **wall-clock**
  deadlines (survive backgrounding), watcher tasks, pause-on-touch banking,
  and the background/foreground sweep. Timer state never touches the
  `@Published` array. Flutter-free by design.
- `ToastContainerView` — groups toasts by position; each row is an
  equality-gated `ToastRow` (`.equatable()`), so a change to one toast never
  re-renders its siblings. The container-level `.animation(motion, value:)`
  is **load-bearing**: it swaps the spring for `easeInOut` under Reduce Motion.
- `ToastView` — per-toast orchestrator: measurement-driven width/wrap state,
  glass surface, drag/tap/press gestures, accessibility.
- `ToastContentView` — the row (leading slot / text column / action button) +
  `AvatarSlot`/`AvatarView`/`CircularProgressView`.
- `ToastMeasurement.swift` — `ToastPreMeasurement`, the synchronous UIKit twin
  of the wrap probe that seeds a row's initial wrap state so its **first**
  layout is already final-height (entering short and growing a frame later
  made the rest of the stack visibly jump); plus the two hidden off-screen probes (wrap decision +
  hugging width) behind an Equatable inputs struct; they only emit
  preferences, `ToastView` owns the handlers.
- `ToastMetrics.swift` — every shared layout constant + the springs. The
  probes must mirror the live layout's insets exactly; routing all values
  through here makes that lockstep structural. Change layout numbers HERE.
- `ToastImageDecoder.swift` — off-main image decode (+ downsampling of large
  sources). `ToastModel.expectsImage` reserves the avatar slot from the first
  frame so pixels landing later never shift the layout.
- `IconView` / `GlassBackground` / `ActionButton` — leaf views.
  `GlassBackground` picks real `glassEffect` (iOS 26+) vs `.ultraThinMaterial`
  (iOS 17–25) vs opaque (Reduce Transparency); those `#available` blocks are
  compile-time API gates — `Capabilities.swift` centralizes only the
  value-level checks (wire strings).
- `Models.swift` — `ToastModel` and friends (all `Equatable` and `public` with
  memberwise inits; the image compares by identity via `ToastImage`); mirrors
  the Dart wire format. Runtime-only fields (`identity`, `shakeToken`,
  `isActionBusy`) are `public internal(set)` — so the bridge reads them but
  only the core mutates them.
- `DynamicIslandGeometry.swift` — device geometry snapshot for `queryGeometry`.
- `Haptics.swift` — maps the toast's haptic enum to `UINotificationFeedbackGenerator`.

### Wire protocol invariants

When changing anything that crosses the channel, keep both sides in lockstep:

- **Enum/event strings are identical on both sides** by exact string match
  (e.g. dismiss reasons `timeout`/`manual`/`swipe`/`action`/`tap`/`replaced`/
  `dismissAll`/`appBackgrounded`; events `shown`/`actionTapped`/`tapped`/
  `dismissed`). `ToastEvent.fromMap` and `reasonFromWire` map them on the Dart side.
- **Ids are minted in Dart** (`ids.dart`): `lt_<sessionPrefix>_<counter>`. The
  `sessionPrefix` is random per isolate and sent in `handshake` (reserved wire
  data — native does not compare it). Native `flushAll`s **unconditionally on
  every handshake**, which is what clears stale toasts after a **hot restart**
  (the old Dart event sink is dead, so those toasts must be dropped silently).
- Command acks are maps: `show`→`{accepted}`, `update`→`{applied}`,
  `dismiss`→`{dismissed}`, `dismissAll`→`{dismissedIds}`. A `false`/missing ack is
  an expected race (toast already gone) — the facade reconciles by locally
  completing the handle so `onDismissed` never hangs.

### Promise / loading contract

`toast.promise<T>(future, ...)` (backed by `ToastEngine.promiseWith`) shows a
spinner, then morphs to success/error.
It **returns the future's value / rethrows its error** — the visual is
best-effort (skipped if the toast was already dismissed; a throwing builder is
logged and never corrupts the outcome) but the caller always owns the result.
Don't change this to swallow results. Promise specs (`loading`/`success`/
`error`) accept `String | Toast | builder` and are validated **eagerly** so
misuse throws `ArgumentError` at the call site.

## Testing notes

- Dart tests use the shared `FakeLiquidToastsPlatform`
  (`liquid_toasts/test/fake_platform.dart`) installed via
  `LiquidToastsPlatform.instance`, with manual control over the
  event stream, which ids native considers "live", an ordered `callLog`, and a
  `showGate` completer to simulate slow native acks (for in-flight-race tests).
- `toast.debugReset()` resets all engine state between tests;
  `toast.debugEmit(event)` injects a native event into the router. Both are
  `@visibleForTesting` — use them rather than reaching into private state.
  `ToastEngine.instance.settle(id)` (import `src/toast_engine.dart`) awaits a
  toast's queued platform ops — use it instead of pumping arbitrary delays.
- `liquid_toasts/test/toaster_test.dart` covers the `toast` API end to end.
- Native behaviors that unit tests can't reach have scripted simulator probes
  in `liquid_toasts/example/lib/`: `bg_probe_demo.dart` (wall-clock deadlines
  across backgrounding + hot-restart flush; drive it with `simctl` foreground/
  background cycles and read the `BGPROBE:` markers) and
  `render_probe_demo.dart` (render isolation; add a temporary NSLog to
  `ToastView.body` and count bodies per patch — expect ~1, not one per
  visible toast).

## Demo / showcase videos

`liquid_toasts/example/lib/showcase.dart` is the recording harness for the
README's showcase clips, which live at the repo root in `assets/showcase/*.mp4`
(full-bleed wallpaper so glass has something to refract, clean gaps between
previews). The exact ffmpeg/simctl regeneration recipe is documented in that
file's header comment.

For ad-hoc demo videos (e.g. showing off a styling change), use the automated
recorder instead of doing it by hand:

```bash
# from the repo root; --target is relative to liquid_toasts/example/
tool/record_demo.sh --target lib/multiline_demo.dart --prefix MULTILINE --contact
```

It launches the example on a booted iOS sim, records a clean hot-restart replay,
and encodes a high-quality **60 fps** mp4 cropped to the toast zone (lead-in
auto-trimmed; `--contact` writes a verification grid). Write new reels with
`runDemoReel()` in `liquid_toasts/example/lib/demo_harness.dart` — a
`name → preview` map that emits the `<prefix>:…:START/END` + `<prefix>:DONE`
markers the recorder keys off (`liquid_toasts/example/lib/multiline_demo.dart`
is the worked example). The `record-demo` skill documents the full workflow.
Note: the sim's display link caps capture at 60 fps; true 120 fps needs a
physical ProMotion device. Toasts animate natively
in SwiftUI, so capture smoothness is independent of Flutter debug/profile mode.
