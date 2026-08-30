# Monorepo plan: standalone SwiftUI package + Flutter plugin

Goal: restructure `liquid-toasts` so the SwiftUI implementation is an
independent Swift package that native iOS apps can install straight from
GitHub, while the Flutter plugin keeps living in the same repo and consumes
that Swift package. Android stays inside the Flutter plugin (not published
independently).

## Decisions (resolved)

| Question | Decision |
| --- | --- |
| CocoaPods support | **Dropped — SwiftPM-only.** The podspec is deleted; Flutter consumers must enable Flutter's SwiftPM mode. In exchange the plugin references the core by relative path: no vendored copy, no sync script, no drift CI. pub.dev publishing is deferred until/unless we revisit (it would need self-containment). |
| Versioning | **Unified `vX.Y.Z` tags**, both packages release together (SwiftPM only resolves bare semver tags). |
| Native API entry point | **`LiquidToast.show(...)`** static facade; module stays `import LiquidToasts`. |
| Canonical URL | **`github.com/SimplifyJobs/liquid-toasts`** — update pubspec metadata, README, and all install snippets (they currently say `rehmatsg/`). |
| Showcase videos | Stay in the repo — the whole pack is 1.6 MiB (videos 384 KB); no weight problem for SwiftPM clones. |
| Flutter-folder identity | Verified against Flutter tooling source: the generated manifest references plugins via `.package(name: <pubspec name>, path: ...)` through a symlink named after the plugin folder's basename. A plugin living at `<repo>/liquid_toasts/` has the right basename in every install mode, so today's checkout-rename caveat disappears. |

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
├── liquid-toasts-swift/
│   ├── Sources/LiquidToasts/      # core: manager, views, scheduler, metrics, models…
│   ├── README.md                  # native quick start
│   ├── Tests/LiquidToastsTests/   # (later)
│   └── Example/                   # (later) tiny native demo app
├── liquid_toasts/                 # the Flutter plugin package
│   ├── pubspec.yaml
│   ├── lib/  test/  android/  example/
│   ├── CHANGELOG.md  README.md  analysis_options.yaml
│   └── ios/
│       └── liquid_toasts/         # plugin Swift package — BRIDGE ONLY
│           ├── Package.swift      # deps: LiquidToasts (path: ../../..) + FlutterFramework
│           └── Sources/liquid_toasts/  # LiquidToastsPlugin.swift, WireDecoding.swift, PrivacyInfo
├── tool/                          # record_demo.sh
├── docs/
├── README.md (umbrella)  LICENSE
│   # no repo-level CHANGELOG: the single CHANGELOG lives with the plugin,
│   # since both packages ship from one version/tag
└── .github/workflows/
```

No podspec, no vendored sources: the core exists exactly once, at
`liquid-toasts-swift/Sources/LiquidToasts`.

### Why `Package.swift` sits at the repo root (not inside `liquid-toasts-swift/`)

SwiftPM can only resolve a git URL whose **repository root** contains
`Package.swift` — it cannot point at a subdirectory of a repo. So for
`https://github.com/SimplifyJobs/liquid-toasts.git` to be installable in
Xcode, the manifest must live at the root. The manifest is thin; its target
uses `path: "liquid-toasts-swift/Sources/LiquidToasts"` so all real content
still lives in the `liquid-toasts-swift/` folder. (Alternative considered:
auto-mirroring the folder into a separate standalone repo via subtree-split
on tag. Cleaner root, but extra infra and two URLs to document — not worth it
now; easy to add later without breaking anyone.)

### Why the Flutter folder is named `liquid_toasts/` (not `flutter/`)

Flutter's SwiftPM integration symlinks each plugin package under a directory
named after the plugin folder's basename and references it as
`.package(name: <pubspec name>, path: ...)`. The basename must therefore be
the Dart package name — the reason today's checkout must be renamed from
`liquid-toasts` to `liquid_toasts`. Putting the plugin in a subfolder named
`liquid_toasts/` makes that identity correct *permanently* — including for
`pub` **git installs**, where pub clones into a hash-named cache dir but the
package root becomes `<clone>/liquid_toasts`.

### How the plugin consumes the core (SwiftPM-only)

The bridge package at `liquid_toasts/ios/liquid_toasts/` declares:

```swift
dependencies: [
  .package(name: "liquid-toasts", path: "../../.."),       // the root core package
  .package(name: "FlutterFramework", path: "../FlutterFramework"),
]
```

This works for the bundled example (path dep) and for consumers installing
via a pubspec **git** dependency, because pub clones the *entire* repo into
its cache — `../../..` from the bridge package resolves to the clone root,
where `Package.swift` lives.

Consequences accepted with the SwiftPM-only decision:

- Flutter consumers must run with SwiftPM enabled
  (`flutter config --enable-swift-package-manager`); document this
  prominently in the README install section. CocoaPods-mode builds will fail
  with a missing-podspec error.
- pub.dev publishing is off the table for now (`dart pub publish` uploads
  only the package directory, so `../../..` would dangle). If we ever want
  pub.dev, we add a release-time vendoring step then — nothing in this
  layout prevents it.

**Verify first (the one structural risk):** Flutter reaches the bridge
package *through a symlink* (`.symlinks/plugins/…` style). If SwiftPM
resolved the relative `../../..` against the symlink's location instead of
the real path, it would escape into the ephemeral build directory and fail.
Smoke-test this exact setup (a scratch monorepo with a two-level path dep
consumed by a Flutter example in SwiftPM mode) **before** executing the full
restructure. If it fails, the fallback is the vendored-copy design from an
earlier revision of this plan (see git history of this file).

## Phased execution

### Phase 0 — de-risk

1. Scratch-verify the symlinked relative path dependency described above.
2. While in there, confirm a native app can add the scratch repo by git URL
   and build the core product.

### Phase 1 — decouple core from Flutter (in place, before any moves)

1. Move `ToastModel.init?(arguments:)` (and the other `init?(_ map:)` wire
   initializers in `Models.swift`) plus `WireDecoding.swift` into the bridge
   side; give the models plain Swift initializers. The one
   `FlutterStandardTypedData` check becomes bridge code that hands the core
   `Data`/`expectsImage`.
2. Confirm the core file set compiles with no `import Flutter` anywhere
   (plugin + wire decoding excluded).
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
- **Native facade (the API iOS devs actually see)** — `LiquidToast`, a
  static facade mirroring the Dart `toast` API so the brand promise
  ("no context required") holds natively:

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
   `liquid-toasts-swift/Sources/LiquidToasts`, iOS 17+, privacy manifest
   resource.
2. `git mv` core sources → `liquid-toasts-swift/Sources/LiquidToasts/`;
   bridge files stay for the plugin package.
3. `git mv` `pubspec.yaml lib test android example analysis_options.yaml
   CHANGELOG.md → liquid_toasts/`; move `ios/` (bridge only) under it.
4. **Delete `liquid_toasts.podspec`.** Update the bridge `Package.swift` to
   depend on the root core package (`path: "../../.."`).
5. Fix relative paths: `example/pubspec.yaml` path dep stays `../`;
   `tool/record_demo.sh` gains the new example path; rewrite `CLAUDE.md`
   for the new layout (delete the folder-rename caveat and the CocoaPods
   mention).
6. Update every URL to `github.com/SimplifyJobs/liquid-toasts` (pubspec
   `homepage`/`repository`, READMEs).
7. Repo-level `README.md` becomes the umbrella (install matrix, links);
   `liquid_toasts/README.md` is the pub-facing one; add
   `liquid-toasts-swift/README.md`.

### Phase 4 — verify everything still builds

- `flutter analyze` + `flutter test` from `liquid_toasts/`.
- Example app builds and runs in SwiftPM mode
  (`flutter config --enable-swift-package-manager`).
- `xcodebuild build -scheme LiquidToasts -destination 'generic/platform=iOS Simulator'`
  against the root package (plain `swift build` can't target iOS).
- Scratch native app: add the GitHub URL at the branch ref, show a toast.
- Scratch Flutter app: pub git dependency (`path: liquid_toasts`), show a toast.
- Re-run the simulator probes (`bg_probe_demo.dart`, `render_probe_demo.dart`).

### Phase 5 — releases & install story

**Versioning: one version, one tag, both packages.** SwiftPM only resolves
bare semver tags (`0.8.0` / `v0.8.0`) — prefixed schemes like `swift-v1.0`
are invisible to it. Ship both from the same `vX.Y.Z` tag; bump together
even when only one side changed (cheap at this project's size).

- **Native iOS (Xcode)**: File → Add Package Dependencies →
  `https://github.com/SimplifyJobs/liquid-toasts.git`, Up to Next Major.
- **Native iOS (Package.swift)**:
  ```swift
  .package(url: "https://github.com/SimplifyJobs/liquid-toasts.git", from: "0.8.0")
  ```
- **Flutter from GitHub** (requires SwiftPM mode enabled):
  ```yaml
  dependencies:
    liquid_toasts:
      git:
        url: https://github.com/SimplifyJobs/liquid-toasts.git
        ref: v0.8.0
        path: liquid_toasts
  ```

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
| `example` | `flutter build ios --no-codesign` in SwiftPM mode |
| `release` (tag only) | all of the above + create GitHub Release |

## Remaining open items

- **Phase 0 symlink verification** is the gating check; everything else in
  the layout is settled. Fallback if it fails: vendored-copy design (see this
  file's git history).
- **Legacy facade**: untouched by this plan; the 1.0 removal is orthogonal.
- **Semantic defaults duplication** (Dart + Swift tables): acceptable now;
  if it ever grows, generate both from one spec file.
- **pub.dev**: deliberately deferred (see Decisions); requires a release-time
  vendoring step if revisited.
