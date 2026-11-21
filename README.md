# Veltrio for iOS

The native iPhone and iPad app, bringing all of Veltrio's features (Stremio addons, torrents, debrid, IPTV/Xtream, Jellyfin/Emby/Plex) to iOS 17+.

The macOS repository, [veltrio-macos](https://github.com/VeltrioApp/veltrio-macos),
is included as a git submodule in `macos/`. Its `Shared/` folder (VeltrioKit) holds the
services, theme and translations, and its views build for iOS too; this
repository adds the iOS shell (`PhoneRootView.swift`) and the Metal video player (`MPVMetalView.swift`).

## Build & run

Prerequisites: Xcode 16+, [`xcodegen`](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```bash
git clone --recurse-submodules https://github.com/VeltrioApp/veltrio-ios
cd veltrio-ios
./scripts/fetch-core.sh
xcodegen generate && open Veltrio.xcodeproj
```

## The core

`core.version` names the [veltrio-core](https://github.com/VeltrioApp/veltrio-core) release to use;
`scripts/fetch-core.sh` downloads `veltrio-core-apple-mobile.zip` into `Core/`
(gitignored), or set `VELTRIO_CORE_DIR=../veltrio-core` to build from a local checkout.

## CI/CD

- `ci.yml` — pushes to main, pull requests, manual runs: fetches the core, generates the project with XcodeGen, and builds for the iOS Simulator.
- `release.yml` — tag `vX.Y.Z` or manual run: archives, signs via App Store Connect API, and uploads to TestFlight.

Organisation secrets used: `CORE_RELEASES_TOKEN` (optional), `ASC_KEY_P8`; variables `APPLE_TEAM_ID`, `ASC_KEY_ID`, `ASC_ISSUER_ID`.

## License

Dual-licensed under either of [Apache-2.0](LICENSE-APACHE) or [MIT](LICENSE-MIT). libmpv is linked via [MPVKit](https://github.com/mpvkit/MPVKit) (LGPL).
