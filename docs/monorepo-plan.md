# Monorepo plan: standalone SwiftUI package + Flutter plugin

Goal: restructure `liquid-toasts` so the SwiftUI implementation is an
independent Swift package that native iOS apps can install straight from
GitHub, while the Flutter plugin keeps living in the same repo and consumes
that Swift package. Android stays inside the Flutter plugin (not published
independently).

## Where we start

The repo is a single Flutter plugin. The good news from auditing the iOS
sources: the Flutter coupling is already tiny and localized.

- Only `LiquidToastsPlugin.swift` (`import Flutter`, channels) and one line in
  `Models.swift` (`map["image"] is FlutterStandardTypedData`) touch Flutter.
- `WireDecoding.swift` decodes `[String: Any]` maps — Flutter-shaped but not
  Flutter-dependent.
- `ToastOverlayHost` discovers the key window generically
  (`UIApplication.connectedScenes`), not via Flutter — it already works in any
  UIKit/SwiftUI app.
- Nothing is `public` today: plugin and rendering code compile as one module.
  Splitting into two modules forces us to design a real public API — which is
  exactly the work needed to make the package usable natively anyway.

## Target layout

```
liquid-toasts/
├── Package.swift                  # ROOT manifest — the standalone SwiftUI package
├── swift/
│   ├── Sources/LiquidToasts/      # core: manager, views, scheduler, metrics, models…
│   ├── Tests/LiquidToastsTests/
│   └── Example/                   # (later) tiny native demo app
├── liquid_toasts/                 # the Flutter plugin package
│   ├── pubspec.yaml
│   ├── lib/  test/  android/  example/
│   ├── CHANGELOG.md  README.md  analysis_options.yaml
│   └── ios/
│       ├── liquid_toasts.podspec
│       └── liquid_toasts/         # plugin Swift package
│           ├── Package.swift      # targets: LiquidToasts (vendored core) + liquid_toasts (bridge)
│           └── Sources/
│               ├── LiquidToasts/      # VENDORED copy of swift/Sources/LiquidToasts (script-synced, CI-checked)
│               └── liquid_toasts/     # bridge only: LiquidToastsPlugin.swift, WireDecoding.swift, PrivacyInfo
├── tool/                          # record_demo.sh, sync_ios_sources.sh
├── docs/
├── README.md  LICENSE  CHANGELOG.md (repo-level)
└── .github/workflows/
```

### Why `Package.swift` sits at the repo root (not inside `swift/`)

SwiftPM can only resolve a git URL whose **repository root** contains
`Package.swift` — it cannot point at a subdirectory of a repo. So for
`https://github.com/SimplifyJobs/liquid-toasts.git` to be installable in
Xcode, the manifest must live at the root. The manifest is thin; its target
uses `path: "swift/Sources/LiquidToasts"` so all real content still lives in
the `swift/` folder. (Alternative considered: auto-mirroring `swift/` into a
separate `liquid-toasts-swift` repo via subtree-split on tag. Cleaner root,
but extra infra and two URLs to document — not worth it now; easy to add
later without breaking anyone if we ever want a pristine standalone repo.)

### Why the Flutter folder is named `liquid_toasts/` (not `flutter/`)

Flutter's SwiftPM integration derives the plugin's package identity from the
plugin's folder name (the reason today's checkout must be renamed from
`liquid-toasts` to `liquid_toasts`, per the README caveat). Putting the
plugin in a subfolder named `liquid_toasts/` makes that identity correct
*permanently* — including for `pub` **git installs**, where pub clones into a
hash-named cache dir but the package root becomes `<clone>/liquid_toasts`.
The re-clone rename caveat disappears. (Verify once with a scratch app.)

### Why the plugin gets a vendored copy of the core (the key decision)

Three installers must keep working for the Flutter package: SwiftPM-mode
Flutter builds, **CocoaPods**-mode Flutter builds (still the default), and —
eventually — pub.dev publishing (which uploads only the package directory).
That rules out the plugin's Swift package reaching outside itself with
`.package(path: "../../..")`: it would work for pub *git* installs (full
clone in the pub cache) but break pub.dev, and CocoaPods can't reference
files outside the pod root at all.

So: `swift/Sources/LiquidToasts` is the **single source of truth**, and
`tool/sync_ios_sources.sh` copies it verbatim into
`liquid_toasts/ios/liquid_toasts/Sources/LiquidToasts/`. CI fails if the two
trees differ (`diff -r`). This is the pattern several production plugins use;
the cost is a mechanical sync step, the payoff is that every installer sees a
self-contained package with zero path tricks:

- **Flutter + SwiftPM**: plugin `Package.swift` declares two targets —
  `LiquidToasts` (vendored core, no Flutter dependency) and `liquid_toasts`
  (bridge, depends on `LiquidToasts` + `FlutterFramework`).
- **Flutter + CocoaPods**: the podspec globs *both* source dirs into the one
  pod module. Because CocoaPods compiles them as a single module, bridge
  files must guard the cross-module import:
  `#if canImport(LiquidToasts)\nimport LiquidToasts\n#endif`
  (the standard dual SwiftPM/CocoaPods plugin idiom; `public` access is
  harmless same-module).
- **Native iOS app**: installs the root package; never sees the vendored copy.

One copy in git twice is the only ugliness, and CI makes drift impossible to
merge.

## Phased execution

### Phase 1 — decouple core from Flutter (in place, before any moves)

1. Move `ToastModel.init?(arguments:)` (and the other `init?(_ map:)` wire
   initializers in `Models.swift`) plus `WireDecoding.swift` into the bridge
   side; give the models plain Swift initializers. The one
   `FlutterStandardTypedData` check becomes bridge code that hands the core
   `Data`/`expectsImage`.
2. Confirm `swift build` of the core file set compiles with no `import
   Flutter` anywhere (plugin + wire decoding excluded).
3. All Dart tests stay green (nothing on the wire changes).

### Phase 2 — design the public Swift API (the real work)

Splitting modules forces access-control decisions; do them deliberately
rather than blanket-`public`ing internals. Two layers:

- **Runtime surface (what the bridge needs, `public` but documented as
  low-level)**: `ToastManager` entry points (`show/update/dismiss/dismissAll/
  flushAll`), `ToastModel` + nested models with memberwise inits, the event
  callback (`onEvent: (ToastEventPayload) -> Void`), `ToastOverlayHost.install()`,
  `DynamicIslandGeometry.snapshot()`. Keep `frames`, measurement, metrics,
  and the SwiftUI views internal.
- **Native facade (the API iOS devs actually see)** — mirrors the Dart
  `toast` API so the brand promise ("no context required") holds natively:

  ```swift
  import LiquidToasts

  let handle = LiquidToast.show("Saved")                    // auto-installs overlay
  LiquidToast.success("Profile updated", title: "Done")
  let h = LiquidToast.loading("Uploading…")
  h.update(message: "Almost there", progress: 0.8)
  h.dismiss()
  h.onDismissed { reason in … }
  let value = try await LiquidToast.promise(work(),         // async morph, rethrows
      loading: "Saving…", success: "Saved", error: "Failed")
  ```

  Ids are minted natively (UUID-based) for native callers; the Dart side
  keeps minting its own `lt_…` ids — the manager only ever sees opaque
  strings, so both coexist on one stack. Action/tap callbacks for native
  callers live in the facade (same "callbacks never cross a wire" shape as
  the Dart engine). Overlay install stays lazy-on-first-show + at Flutter
  plugin registration, unchanged.

  Scope check: semantic defaults (durations/maxLines/haptics) currently live
  only in Dart (`semantic_defaults.dart`). The facade needs a Swift
  equivalent; keep the two tables in lockstep with a comment cross-reference
  (they're small and change rarely).

### Phase 3 — restructure directories

All moves via `git mv` (history follows):

1. Root `Package.swift`: product `LiquidToasts`, target at
   `swift/Sources/LiquidToasts`, iOS 17+, privacy manifest resource.
2. `git mv` core sources → `swift/Sources/LiquidToasts/`; bridge files stay
   for the plugin package.
3. `git mv` `pubspec.yaml lib test android example analysis_options.yaml
   CHANGELOG.md → liquid_toasts/`; move `ios/` (bridge + podspec) under it.
4. Add the vendored core dir + `tool/sync_ios_sources.sh`; update the plugin
   `Package.swift` (two targets) and the podspec
   (`source_files` = both globs, single privacy-manifest resource bundle).
5. Fix relative paths: `example/pubspec.yaml` path dep stays `../`;
   `tool/record_demo.sh` gains the new example path; rewrite `CLAUDE.md`
   for the new layout (and delete the folder-rename caveat).
6. Repo-level `README.md` becomes the umbrella (install matrix, links);
   `liquid_toasts/README.md` is the pub-facing one; add `swift/README.md`.

### Phase 4 — verify everything still builds

- `flutter analyze` + `flutter test` from `liquid_toasts/`.
- Example app builds and runs in **both** modes: SwiftPM
  (`flutter config --enable-swift-package-manager`) and CocoaPods
  (`pod lib lint` on the podspec too).
- `xcodebuild build -scheme LiquidToasts -destination 'generic/platform=iOS Simulator'`
  against the root package (plain `swift build` can't target iOS).
- Scratch native app: add the GitHub URL at the branch ref, show a toast.
- Scratch Flutter app: pub git dependency (`path: liquid_toasts`), show a toast.
- Re-run the simulator probes (`bg_probe_demo.dart`, `render_probe_demo.dart`).

### Phase 5 — releases & install story

**Versioning: one version, one tag, both packages.** SwiftPM only resolves
bare semver tags (`0.8.0` / `v0.8.0`) — prefixed schemes like `swift-v1.0`
are invisible to it — so independent versioning inside one repo isn't
practical. Ship both from the same `vX.Y.Z` tag; bump together even when only
one side changed (cheap at this project's size).

- **Native iOS (Xcode)**: File → Add Package Dependencies →
  `https://github.com/SimplifyJobs/liquid-toasts.git`, Up to Next Major.
- **Native iOS (Package.swift)**:
  ```swift
  .package(url: "https://github.com/SimplifyJobs/liquid-toasts.git", from: "0.8.0")
  ```
- **Flutter from GitHub**:
  ```yaml
  dependencies:
    liquid_toasts:
      git:
        url: https://github.com/SimplifyJobs/liquid-toasts.git
        ref: v0.8.0
        path: liquid_toasts
  ```
- **Flutter from pub.dev (later)**: `dart pub publish` from `liquid_toasts/`
  works as-is thanks to the vendored core; add sync-check to the publish
  script.

**GitHub Actions on tag push `v*`**: run the full CI suite, then create a
GitHub Release with notes drawn from `CHANGELOG.md`. Releases are
documentation + discoverability; SwiftPM and pub both resolve from the git
tag itself, so no artifacts need attaching (an `.xcframework` attachment can
come later if we ever want binary distribution).

### Phase 6 — CI (GitHub Actions, macOS runner for iOS jobs)

| Job | What |
| --- | --- |
| `dart` | `flutter analyze` + `flutter test` in `liquid_toasts/` |
| `swift` | `xcodebuild build/test` of the root package (iOS Simulator destination) |
| `sync` | `diff -r swift/Sources/LiquidToasts liquid_toasts/ios/liquid_toasts/Sources/LiquidToasts` |
| `example` | `flutter build ios --no-codesign`, SwiftPM and CocoaPods matrix |
| `release` (tag only) | all of the above + create GitHub Release |

## Caveats / open items

- **Repo weight for SwiftPM consumers**: SwiftPM clones the whole repo, and
  `assets/showcase/*.mp4` ride along for every native consumer. Move the
  videos to GitHub Release assets (or a `media` branch) and hot-link them
  from the README as part of this work.
- **CocoaPods `canImport` guard**: verify the bridge compiles in both modes
  early (Phase 1/3 boundary) — it's the one structural trick in the plan.
- **Folder-identity assumption for pub git installs**: verify with a scratch
  app that the `liquid_toasts/` subfolder indeed satisfies Flutter's SwiftPM
  identity derivation from the pub cache (expected per the current caveat's
  mechanics, but cheap to confirm).
- **Legacy facade**: untouched by this plan; the 1.0 removal is orthogonal.
- **Semantic defaults duplication** (Dart + Swift tables): acceptable now;
  if it ever grows, generate both from one spec file.
