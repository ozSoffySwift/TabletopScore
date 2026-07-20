# Claude Code prompt — TabletopScore

Copy everything below the line into Claude Code, run from an empty project folder containing `TabletopScore-Spec.md`.

---

Build an iOS app called **TabletopScore** (App Store name: "TabletopScore: Board Game Music") — a background-music player for board game sessions. The full spec is in `TabletopScore-Spec.md` in this folder; read it first and follow it. Key decisions, already made:

**Stack:** SwiftUI, SwiftData, AVFoundation. iOS 17+, iPhone-first. MVVM with `@Observable` view models. No third-party dependencies except (optionally) Nuke for image caching — prefer plain `AsyncImage` with a small disk cache first.

**Core concept:** Netflix/Disney+-style dark browse UI (background #0B0B0F, accent #E6A23C) with a hero carousel and horizontally scrolling category rows. Playlists of music are organized by board-game context: genre (War Games, 18xx & Trains, Eurogames, Horror, Fantasy…), style (Heavy Strategy, Co-op, Deck Builders…), game length (Filler/Standard/Epic/Marathon), player count (Solo, Two-Player, 3–4, Party 5+), competitive vs cooperative, and mood. A playlist can appear in multiple categories.

**Media strategy — do not bundle audio.** The app fetches a remote `catalog.json` manifest (shape defined in spec §6.1) listing ≥60 tracks with stream URLs, and upserts it into SwiftData (Track, Playlist, Category, PlaybackState models — see spec §4). AVQueuePlayer streams the URLs directly. For development, generate a local `catalog.json` with 60+ entries using SoundHelix test MP3s (https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3 … -Song-17.mp3, cycled with distinct titles/durations) and serve it from a bundled fixture behind a `CatalogSource` protocol so the base URL can be swapped to a real CDN later. Artwork: use solid-color/gradient placeholder art generated in code, keyed by playlist id (real box art is a licensing question, deferred).

**Player requirements:** background audio (`UIBackgroundModes: audio`, AVAudioSession `.playback`), lock-screen/Control Center controls via MPNowPlayingInfoCenter + MPRemoteCommandCenter, play/pause/next/prev/seek/shuffle/repeat, interruption + route-change handling, playlist looping by default, sleep timer, 4 s crossfade default. Persistent mini player bar above the tab bar; tap expands to full Now Playing screen (large art, scrubber, controls, up-next).

**Screens:** Home (hero + rows), Category "see all" grid, Playlist detail (art, description, track list, Play/Shuffle), Now Playing, Search (name/tag/mood), Library (favorites, recently played), Settings (cellular streaming toggle, crossfade, cache size). Tab bar: Home, Search, Library, Settings.

**How to work:**
1. Read `TabletopScore-Spec.md` fully.
2. Create the Xcode project structure (use XcodeGen or Tuist if available, otherwise create the `.xcodeproj` layout you can and give me exact Xcode steps for anything that must be done in the GUI, e.g. capabilities).
3. Build in this order: SwiftData models + catalog sync with fixture catalog → PlayerService with background audio → Home browse UI → mini player + Now Playing → playlist detail → search/library/settings → polish (shimmer loading, haptics, accessibility labels, Dynamic Type).
4. After each milestone, build with `xcodebuild` for the iOS Simulator and fix all errors and warnings before moving on. Write unit tests for catalog sync/diffing and the queue logic in PlayerService.
5. Keep everything in String Catalogs, VoiceOver-label all cards and controls, and honor Reduce Motion for the auto-advancing hero carousel.

Design reference: the Figma mockup at https://www.figma.com/design/QMIL6nVDoTasUgyRQ8h0Ea (Home, Now Playing, Playlist Detail) — match its layout, spacing, and color scheme.
