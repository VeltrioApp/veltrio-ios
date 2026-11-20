# Veltrio for iOS

In progress: the iPhone and iPad app, the macOS app's features and look.

The macOS repository, [veltrio-macos](https://github.com/VeltrioApp/veltrio-macos),
is a git submodule in `macos/`. Its `Shared/` folder (VeltrioKit) holds the
services, theme and translations, and its views build for iOS too; this
repository adds the iOS app around them (and the player, drawn with Metal).

```bash
git clone --recurse-submodules https://github.com/VeltrioApp/veltrio-ios
./scripts/fetch-core.sh
xcodegen generate && open Veltrio.xcodeproj
```

**Planned stack:** SwiftUI (iPhone, iPad), XcodeGen project like veltrio-macos, iOS 16+.

## The core

`core.version` names the veltrio-core release to use;
`scripts/fetch-core.sh` downloads its `veltrio-core-apple-mobile.zip` into `Core/`
(gitignored). Needs [`gh`](https://cli.github.com) (signed in), or `VELTRIO_CORE_DIR=../veltrio-core` to
build from a local checkout.

Link `Core/veltrioFFI.xcframework` (embed & sign) and add `Core/Bindings/veltrio.swift` to the target. libmpv: MPVKit supports iOS.

## CI/CD

- `ci.yml` — pushes to main, pull requests, manual runs: fetches the core, then builds and tests once
  `project.yml` (XcodeGen) exists. Until then it only checks the core download.
- `release.yml` — tag `vX.Y.Z`: archive, sign and upload to TestFlight. Skipped until the project exists.

Organisation secrets used: `CORE_RELEASES_TOKEN` (optional: the repositories are public, so the workflow token can read core releases), `APPLE_DISTRIBUTION_P12`, `APPLE_DISTRIBUTION_PASSWORD`, `ASC_KEY_P8`; variables `APPLE_TEAM_ID`, `ASC_KEY_ID`, `ASC_ISSUER_ID`.
