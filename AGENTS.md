# AGENTS.md

Tulis for iOS/iPadOS: a native port of the Android app [Fadhil-Sabar/tulis](https://github.com/Fadhil-Sabar/tulis). Swift 6, SwiftUI with PencilKit, built as a SwiftPM package with [xtool](https://xtool.sh) so it can be developed on Linux. The UI language is Indonesian.

## Layout

- `Sources/Tulis/` the app (SwiftUI, UIKit, PencilKit). Every file is wrapped in `#if canImport(UIKit)` so the package still builds on Linux.
- `Sources/TulisCore/` models and file formats. Foundation only, no UIKit, so it runs and is tested on Linux.
- `Tests/TulisCoreTests/` Swift Testing tests for `TulisCore`.
- `xtool.yml` bundle ID and packaging config for xtool.

## Build and test

```
swift test                 # TulisCore, works on Linux and macOS
xtool dev                  # build, sign, install to a connected iPhone (Linux)
```

CI runs `swift test` on Linux and `xcodebuild build` for the iOS Simulator on macOS. Both must pass.

## Rules

- Keep parity with the Android app. Enum order in `TulisCore/Models.swift` must match `model/Models.kt` because ordinals are written to files.
- The `.tulis` format is shared with Android. Format changes are designed in the Android repo first (`PageCodec.VERSION`, `NotebookArchive.FORMAT`) and mirrored here with a test.
- The app requests no permissions and has no network code. Do not add dependencies without discussion.
