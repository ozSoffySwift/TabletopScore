# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

TabletopScore: an iOS 17+ background-music player for board game sessions (SwiftUI, SwiftData, AVFoundation, no third-party dependencies). The authoritative product spec is `TabletopScore-Spec.md`; deviations from it are listed at the bottom of `README.md`.

## Commands

```sh
# Build (iOS Simulator)
xcodebuild -project TabletopScore.xcodeproj -scheme TabletopScore \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# All unit tests
xcodebuild -project TabletopScore.xcodeproj -scheme TabletopScore \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test

# Single test class / case
xcodebuild ... test -only-testing:TabletopScoreTests/PlayQueueTests
xcodebuild ... test -only-testing:TabletopScoreTests/CatalogSyncTests/testResyncRemovesDeletedPlaylist

# Run in simulator
xcrun simctl install "iPhone 17 Pro" <DerivedData>/Build/Products/Debug-iphonesimulator/TabletopScore.app
xcrun simctl launch "iPhone 17 Pro" com.tabletopscore.app
```

There is no linter. Keep the build at zero warnings — `appintentsmetadataprocessor` warnings are toolchain noise and can be ignored.

## Project file rules

- `TabletopScore.xcodeproj/project.pbxproj` is hand-written (objectVersion 77) and uses `PBXFileSystemSynchronizedRootGroup` for `TabletopScore/` and `TabletopScoreTests/`. **New source files are picked up automatically — never add per-file entries to the pbxproj.**
- `Support/Info.plist` must stay OUTSIDE the synced `TabletopScore/` folder: it merges with the generated Info.plist via `INFOPLIST_FILE`, and moving it inside causes a "multiple commands produce Info.plist" build failure. It carries `UIBackgroundModes: audio` (required for background playback).
- User-facing strings go through String Catalogs (`TabletopScore/Resources/Localizable.xcstrings`, auto-extracted at build via `SWIFT_EMIT_LOC_STRINGS`).

## Architecture

Data flows one way: **catalog.json manifest → CatalogSyncService → SwiftData → @Query-driven UI**, with `PlayerService` as the single mutable runtime object injected via `.environment`.

- **Catalog** (`TabletopScore/Catalog/`): `CatalogSource` protocol abstracts where `catalog.json` comes from — `BundledCatalogSource` (dev fixture in `Resources/catalog.json`) vs `RemoteCatalogSource` (CDN with ETag/304). The swap point is `RootView.initialSync()`. `CatalogSyncService.apply()` is a pure upsert/diff: manifest ids are the source of truth, user state (`isFavorite`, `lastPlayedAt`, `playCount`) survives resyncs, ids missing from the manifest are deleted. Syncs are skipped unless the manifest `version` changes — when editing the fixture, **bump `version` or the change won't apply** on existing installs.
- **Models** (`TabletopScore/Models/`): ids are String catalog slugs (not the spec's UUIDs) so sync can diff by manifest id. `Playlist.orderedTrackIDs` preserves manifest track order because SwiftData to-many relationships don't guarantee order — always read tracks via `playlist.orderedTracks`. The spec's `Category` is named `GameCategory`.
- **Player** (`TabletopScore/Player/`): three layers, deliberately separated:
  - `PlayQueue<Element>` — pure struct holding ordering/shuffle/repeat logic; unit-tested, no AVFoundation. Shuffle keeps the current item as head; auto-advance vs user-initiated advance differ under repeat-one.
  - `CrossfadeEngine` — two `AVPlayer`s behind one facade (an `AVQueuePlayer` cannot overlap items, which crossfade requires). Owns volume ramps, per-player end observation, periodic ticks. All `@MainActor`.
  - `PlayerService` — the `@Observable` facade views talk to. Owns the queue + engine, MPNowPlayingInfoCenter/MPRemoteCommandCenter, interruption/route-change handling, sleep timer, duck, cellular gating (`NetworkMonitor` + `AppSettings.allowCellularStreaming`), and persistence of `PlaybackStateRecord` (queue restores paused at position on relaunch via `configure(context:)`).
  - Crossfade triggering lives in `PlayerService.handleTick`: the queue advances *when the fade starts*, not when the outgoing track ends; `handleTrackEnded` is the no-crossfade fallback path. Keep those two paths consistent when changing advance semantics.
- **Artwork**: there is no bundled or remote art in v1. `PlaceholderArt` renders deterministic gradients keyed by playlist/track id and is used both by SwiftUI views (`ArtworkView`) and for lock-screen artwork (UIImage rendering, cached). Same key must always produce the same art.
- **Games**: the primary browse axis. `Game` maps to exactly one curated `playlist` — the mapping is manifest content (`games[].playlistId`), never app logic. `Game.lastPlayedAt` (set at play call sites, not in PlayerService) drives the "Recently Played Games" row.
- **Fixture**: `TabletopScore/Resources/catalog.json` (17 playlists, 29 categories, 105 games; tracks are Kevin MacLeod CC-BY MP3s in `DevCDN/audio/`, streamed from `Tools/serve_devcdn.sh` on localhost:8787) is generated by `Tools/gen_catalog.py` from `Tools/music_manifest.json` (produced by `Tools/fetch_music.py`) — edit and rerun scripts rather than hand-editing JSON, and bump `VERSION`. `CatalogSyncTests.testBundledFixtureDecodesAndMeetsSpecMinimums` enforces spec minimums (≥60 tracks/≥12 playlists/≥20 categories/≥100 games) and referential integrity.

## Licensing invariants

- Tracks carry `composer`/`license`/`sourceURL`/`creditText` through manifest → SwiftData. The **Settings → Music Credits** screen is what satisfies CC-BY attribution — never remove it while CC-BY tracks ship. `Tools/sources.csv` is the download audit trail. Approved sources and rules live in `LICENSING.md` — ads are planned, so only commercial-safe licenses (CC-BY / Pixabay / PD); never add CC-NC content in any variant.
- Games' `attribution` manifest field (BoardGameGeek) must never be stripped; BGG use is non-commercial-with-attribution until a commercial license exists.

## Conventions

- MVVM-lite: views read SwiftData via `@Query` directly; `@Observable` + `@MainActor` for services; Swift 5 language mode.
- Tests are hosted XCTest (`@testable import TabletopScore`) with in-memory `ModelContainer`s; shuffle tests inject a seeded `RandomNumberGenerator`.
- Every interactive control gets an explicit `accessibilityLabel`; motion (hero auto-advance, shimmer) must respect `accessibilityReduceMotion`.
