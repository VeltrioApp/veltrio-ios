# Veltrio for iOS

Not started yet. This repository holds the CI/CD and the pinned
[veltrio-core](https://github.com/VeltrioApp/veltrio-core) release the
app will build on.

**Planned stack:** SwiftUI (iPhone, iPad), XcodeGen project like veltrio-macos, iOS 16+.

## The core

`core.version` names the veltrio-core release to use;
`scripts/fetch-core.sh` downloads its `veltrio-core-apple-mobile.zip` into `Core/`
(gitignored). Needs [`gh`](https://cli.github.com) signed in with access
to `VeltrioApp/veltrio-core`, or `VELTRIO_CORE_DIR=../veltrio-core` to
build from a local checkout.

Link `Core/veltrioFFI.xcframework` (embed & sign) and add `Core/Bindings/veltrio.swift` to the target. libmpv: MPVKit supports iOS.

## CI/CD

- `ci.yml` — pull requests and manual runs (macOS minutes count ×10 on a private repo): fetches the core, then builds and tests once
  `project.yml` (XcodeGen) exists. Until then it only checks the core download.
- `release.yml` — tag `vX.Y.Z`: archive, sign and upload to TestFlight. Skipped until the project exists.

Organisation secrets used: `CORE_RELEASES_TOKEN`, `APPLE_DISTRIBUTION_P12`, `APPLE_DISTRIBUTION_PASSWORD`, `ASC_KEY_P8`; variables `APPLE_TEAM_ID`, `ASC_KEY_ID`, `ASC_ISSUER_ID`.
