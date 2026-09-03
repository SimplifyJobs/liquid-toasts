# liquid-toasts

Premium, **natively-rendered** toasts — drawn on an overlay above your app in
**SwiftUI**, with a springy slide-in entrance, per-position vertical stacking,
and async **loading** toasts. No view controller, no `BuildContext`, no
environment plumbing.

This repo ships the same toaster in two flavors:

- **[`LiquidToasts`](liquid-toasts-swift/README.md)** — a standalone SwiftUI
  package for native iOS apps (`LiquidToast.show("Saved")`).
- **[`liquid_toasts`](liquid_toasts/README.md)** — a Flutter plugin
  (`toast.success('Saved')`) that renders through that same SwiftUI package on
  iOS, and through an equivalent Jetpack Compose implementation on Android.

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

## Install

Both packages ship from the same repo and the same `vX.Y.Z` tag.

### Native iOS — Xcode

File → Add Package Dependencies… →
`https://github.com/SimplifyJobs/liquid-toasts.git`, *Up to Next Major*. Add
the **LiquidToasts** library to your app target.

### Native iOS — `Package.swift`

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

```swift
import LiquidToasts

LiquidToast.success("Profile updated")
```

Requires iOS 17+ (real Liquid Glass activates on iOS 26+; frosted below).

### Flutter

```yaml
dependencies:
  liquid_toasts:
    git:
      url: https://github.com/SimplifyJobs/liquid-toasts.git
      ref: v0.8.0
      path: liquid_toasts
```

> **⚠️ Swift Package Manager is required.**
>
> The plugin's iOS side is **SwiftPM-only** — there is no podspec. Enable
> Flutter's SwiftPM mode once per machine:
>
> ```bash
> flutter config --enable-swift-package-manager
> ```
>
> Without it, an iOS build fails with a missing-podspec error. Android needs no
> extra setup.

```dart
import 'package:liquid_toasts/liquid_toasts.dart';

toast.success('Saved to favorites');
```

## Releases

Both packages ship from one `vX.Y.Z` git tag — notes live on the
[Releases page](https://github.com/SimplifyJobs/liquid-toasts/releases), and
SwiftPM and pub resolve straight from the tag.

## Layout

```
Package.swift            # root manifest for the standalone SwiftUI package
liquid-toasts-swift/     # its sources (Sources/LiquidToasts) + native README
liquid_toasts/           # the Flutter plugin: lib/ test/ android/ example/
  └── ios/liquid_toasts/ # the plugin's Swift package: the bridge, plus a
                         # symlink to the core sources above
tool/  docs/  assets/
```

The root `Package.swift` is thin — a manifest pointing at
`liquid-toasts-swift/Sources/LiquidToasts` — and lives at the repo root because
SwiftPM can only resolve a git URL whose repository root holds a manifest. The
plugin's package compiles that same folder through
`ios/liquid_toasts/Sources/LiquidToasts`, a symlink, so the SwiftUI core exists
exactly once with no vendored copy to drift.

Why a symlink and not a package dependency: Flutter resolves a plugin through a
symlink in the consuming app
(`ios/Flutter/ephemeral/Packages/.packages/<plugin>`), and SwiftPM resolves a
manifest's relative paths against that symlink rather than the checkout it
points into. A dependency reaching above the plugin's own folder therefore
lands in the app's ephemeral directory and fails resolution. The source symlink
has no such problem — the filesystem follows it from its real location.

## Docs

- [Flutter plugin README](liquid_toasts/README.md) — full Dart API, migration
  notes, platform matrix
- [Native SwiftUI README](liquid-toasts-swift/README.md) — `LiquidToast` quick
  start
- [Monorepo plan](docs/monorepo-plan.md) — why the repo is shaped this way
- [CHANGELOG](liquid_toasts/CHANGELOG.md)

## License

See [LICENSE](LICENSE).
