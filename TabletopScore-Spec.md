# TabletopScore: Board Game Music
### (working title "TabletopScore"; display name "TabletopScore"; App Store name "TabletopScore: Board Game Music")
## iOS App Specification v1.0

**Platform:** iOS 17+ (iPhone & iPad) · **UI:** SwiftUI · **Persistence:** SwiftData · **Audio:** AVFoundation / AVPlayer

---

## 1. Product Overview

TabletopScore plays curated background music and ambience for board game sessions. Users browse a Netflix/Disney+-style catalog of playlists organized by game genre, style, length, and player count, then play them with a full-featured media player that keeps running for the entire session.

### Goals
- One-tap ambience matched to the game on the table (e.g. "War Games", "18xx / Trains", "Solo Night").
- Zero-friction playback: works in background, with lock-screen controls, for 1–6+ hour sessions.
- Small app footprint: minimum 60 tracks in the catalog, **streamed — not bundled** (see §6).

### Non-Goals (v1)
- No user uploads, no social features, no music creation.
- No offline-first requirement (offline caching is a v1.1 enhancement).

---

## 2. Information Architecture — game-first browsing

The primary browse axis is the **board game on the table**, not the playlist.
Users pick a real game (box art + name visible) and the app plays that game's
curated soundtrack. Playlist/mood browsing remains as a secondary axis.

### 2.1 Rows on Home
Each row is a horizontally scrolling carousel of **game box-art cards**
(2:3 portrait, name beneath), like Netflix:

| Row | Contents |
|---|---|
| Featured (hero carousel) | Editor-picked games, 16:9 hero art, "Play soundtrack" button |
| Recently Played Games | Auto-generated from listening history |
| Popular Games | Top of the catalog by `popularityRank` |
| By Game Genre | War Games, 18xx & Trains, Eurogames, Dungeon Crawlers, Horror, Sci-Fi, Fantasy, Party |
| By Game Style | Heavy Strategy, Ameritrash, Abstract, Deck Builders, Roll & Write |
| By Game Length | Filler (<30 min), Standard (30–90 min), Epic (90 min–3 h), Marathon (3 h+) |
| By Player Count | Solo, Two-Player Duels, 3–4 Players, Party (5+) |
| Competitive vs. Co-op | Competitive, Cooperative, Team vs. Team |
| Browse by Mood (secondary) | Playlist posters: Tense, Calm, Epic, Mysterious, Upbeat |
| Favorites | User-hearted playlists |

Games and playlists can belong to multiple categories (many-to-many).

**Curated matching:** every game maps to exactly **one** playlist
(`Game.playlist`), hand-assigned in the remote manifest (e.g. Scythe →
"Drums of War", Brass: Birmingham → "Steam & Steel"). There is **no**
matching logic in the app — re-curation is a server-side manifest edit,
no app update required.

### 2.2 Screens
1. **Home (Browse)** — hero carousel + game rows + secondary mood section. Dark theme, box-art cards.
2. **Game detail** — large box art, name, player-count / play-time / genre chips, the mapped playlist with a big Play button and its track list inline. One tap from game to music.
3. **Category page** — vertical grid of all games in a category ("See All"); playlist grid for mood categories.
4. **Playlist detail** — cover art, description, track list, Play/Shuffle buttons, duration, tags.
5. **Now Playing (full player)** — large artwork, scrubber, controls, queue, sleep timer.
6. **Mini player** — persistent bar above the tab bar, tap to expand (matches Netflix/Spotify pattern).
7. **Search** — games first, then playlists; by name, tag, mood.
8. **Library** — favorites, recently played, downloads (v1.1).
9. **Settings** — appearance, crossfade length, cellular streaming toggle, cache size.

Tab bar: **Home · Search · Library · Settings**.

---

## 3. Visual Design (Netflix / Disney+ style)

- **Theme:** dark background (#0B0B0F), white/gray text, one accent color (e.g. amber #E6A23C — "candlelight on a game table").
- **Hero carousel:** full-width, auto-advancing, paged (`TabView` with `.page` style), gradient scrim over artwork with title + Play button.
- **Rows:** `ScrollView(.horizontal)` + `LazyHStack`; 2:3 portrait posters for playlists, 16:9 landscape cards for featured.
- **Artwork:** the user's stated intent is to use original board-game box art.
  ⚠️ **Legal note:** box art is copyrighted by publishers. For an App Store release, either (a) obtain publisher permission, (b) use BoardGameGeek-hosted images under their API terms with attribution, or (c) commission original genre artwork (safest). The spec supports any image URL, so this is a content decision, not an architectural one.
- **Loading:** shimmer/skeleton placeholders; `AsyncImage` (or Kingfisher/Nuke) with memory+disk cache.
- Rounded corners 12 pt, subtle parallax on hero, haptics on play.

---

## 4. Data Model (SwiftData)

```swift
import SwiftData

@Model final class Track {
    @Attribute(.unique) var id: UUID
    var title: String
    var artist: String
    var duration: TimeInterval
    var streamURL: URL          // remote media URL (see §6)
    var artworkURL: URL?
    var fileSizeBytes: Int?     // for cache management
    var isDownloaded: Bool = false
    var localFileName: String?  // set when cached offline
    var playCount: Int = 0
    var playlists: [Playlist] = []
    init(...) { ... }
}

@Model final class Playlist {
    @Attribute(.unique) var id: UUID
    var name: String
    var summary: String
    var artworkURL: URL?
    var heroArtworkURL: URL?    // 16:9 for featured row
    var isFeatured: Bool = false
    var sortIndex: Int = 0
    @Relationship(inverse: \Track.playlists) var tracks: [Track] = []
    var categories: [Category] = []
    var isFavorite: Bool = false
    var lastPlayedAt: Date?
}

@Model final class Category {
    @Attribute(.unique) var id: UUID
    var name: String            // "War Games"
    var group: CategoryGroup    // .genre, .style, .length, .playerCount, .mode, .mood
    var sortIndex: Int
    @Relationship(inverse: \Playlist.categories) var playlists: [Playlist] = []
    @Relationship(inverse: \Game.categories) var games: [Game] = []
}

@Model final class Game {       // primary browse axis (§2)
    @Attribute(.unique) var id: UUID
    var name: String            // "Scythe"
    var artworkURL: URL?        // 2:3 box art (remote, see §6)
    var heroArtworkURL: URL?    // 16:9 for the featured hero carousel
    var playerCountMin: Int
    var playerCountMax: Int
    var playTimeMinutes: Int
    var popularityRank: Int     // drives the "Popular Games" row
    var isFeatured: Bool = false
    var categories: [Category] = []
    var playlist: Playlist?     // the ONE curated soundtrack, assigned in the manifest
    var lastPlayedAt: Date?     // drives "Recently Played Games"
}

enum CategoryGroup: String, Codable {
    case genre, style, length, playerCount, mode, mood
}

@Model final class PlaybackState {   // singleton row: resume where you left off
    var currentTrackID: UUID?
    var positionSeconds: Double
    var queueTrackIDs: [UUID]
    var repeatMode: Int
    var isShuffled: Bool
}
```

**Catalog sync:** SwiftData is the local store; the source of truth is a remote **catalog JSON manifest** (§6.1). On launch (and every 24 h), the app fetches the manifest, diffs by `id` + `updatedAt`, and upserts Tracks/Playlists/Categories. The app therefore ships with ~0 MB of media and the catalog can grow without app updates.

---

## 5. Media Player

### 5.1 Engine
- `AVQueuePlayer` wrapping remote URLs — **AVPlayer streams progressively; it never needs the whole file before playing.**
- `AVAudioSession` category `.playback` → keeps playing when the screen locks or app backgrounds (requires `UIBackgroundModes: audio` in Info.plist).
- `MPNowPlayingInfoCenter` + `MPRemoteCommandCenter` → lock screen / Control Center / CarPlay / AirPods controls.
- Interruption handling (phone call → pause, resume after) and route-change handling (unplugging headphones → pause).

### 5.2 Controls (basic set, per requirement)
Play/Pause · Next/Previous track · Seek scrubber · Volume (system) · Shuffle · Repeat (off/all/one) · AirPlay picker.

### 5.3 Board-game-specific extras
- **Loop playlist by default** — sessions outlast playlists.
- **Sleep/session timer** ("stop in 90 min").
- **Crossfade** (0–10 s, default 4 s) so ambience never hard-cuts.
- Optional **ducking hint**: single tap on mini player lowers volume 50% for table talk.

---

## 6. Linking 60+ Media Files Without Bundling Them — Solution Options

The requirement: ≥60 tracks available in the app, downloaded **on demand only**, keeping the app binary small. All options below share one pattern: the app stores only **URLs + metadata** (a few KB per track); audio bytes move only when the user presses play.

### Option A — Cloud storage + CDN with a JSON manifest ⭐ Recommended
Host MP3/AAC files in object storage (Cloudflare R2, AWS S3 + CloudFront, or Bunny CDN). Publish one `catalog.json` manifest listing every track's metadata and URL. App fetches manifest → upserts into SwiftData → `AVPlayer(url:)` streams on demand.

- **Pros:** dead simple; progressive streaming built into AVPlayer; add/rename/reorder tracks without an app update; R2 has zero egress fees (~$0.015/GB-month storage — 60 tracks ≈ 300 MB ≈ pennies/month); works with signed URLs if you need protection.
- **Cons:** you run a (tiny) backend surface; plain files are easy to rip unless you sign URLs.
- **Effort:** ~1 day.

### Option B — HLS streaming (`.m3u8`)
Pre-segment each track with Apple's `mediafilesegmenter`/ffmpeg and serve HLS playlists from the same CDN.

- **Pros:** instant start, adaptive bitrate on bad Wi-Fi, native `AVPlayer` support, `AVAssetDownloadTask` gives you industrial-grade offline downloads later, supports FairPlay DRM if ever needed.
- **Cons:** preprocessing pipeline; more files to manage. Overkill for fixed-bitrate background music, but the "most correct" Apple answer.
- **Effort:** 2–3 days.

### Option C — CloudKit public database + CKAsset
Store Track records in CloudKit's public DB with the audio as `CKAsset`; app queries CloudKit instead of fetching JSON.

- **Pros:** zero servers, free at this scale (Apple hosts), catalog editable in CloudKit Dashboard, auth built in.
- **Cons:** CKAsset returns a downloaded file URL rather than a true stream (full file downloads before play — acceptable for 3–5 MB tracks, worse for 20-minute ambience); Apple-ecosystem lock-in.
- **Effort:** ~1–2 days.

### Option D — Free hosted catalogs (no hosting at all)
Link directly to permissively licensed tracks on Pixabay Music, Free Music Archive, or Internet Archive (CC0/CC-BY). The manifest just points at their CDN URLs.

- **Pros:** $0, no infrastructure, fastest path to 60+ real tracks for a prototype.
- **Cons:** URLs can break without notice; licensing must be checked per track; no control over availability or quality. Fine for the MVP/demo, risky for production.
- **Effort:** hours.

### Option E — Apple On-Demand Resources (ODR)
Bundle tracks as ODR tags; the App Store hosts them and iOS fetches tags on demand and purges under storage pressure.

- **Pros:** no backend at all, Apple-hosted, free.
- **Cons:** ODR assets download fully before use (no streaming), 2 GB cap per tag set, catalog updates require an App Store release. This defeats the "grow the catalog freely" goal — listed for completeness, not recommended.

### Recommendation
**A now, B later.** Ship v1 with Option A (R2/S3 + `catalog.json` + AVPlayer streaming) — it satisfies "smart and fast" with the least machinery. If usage grows or you add long ambience tracks, upgrade the same URLs to HLS (Option B) with no data-model changes: `streamURL` simply starts pointing at `.m3u8` files. Use Option D's free CC0 tracks as the initial 60-track content while sourcing final music.

### 6.1 `catalog.json` shape
```json
{
  "version": 14,
  "updatedAt": "2026-07-13T08:00:00Z",
  "categories": [
    { "id": "war", "name": "War Games", "group": "genre", "sortIndex": 1 }
  ],
  "playlists": [
    {
      "id": "drums-of-war",
      "name": "Drums of War",
      "summary": "Martial percussion and low brass for long campaigns.",
      "artwork": "https://cdn.tabletopscore.io/art/drums-of-war.jpg",
      "categories": ["war", "epic-length", "competitive"],
      "featured": true,
      "trackIds": ["t001", "t002", "t003"]
    }
  ],
  "tracks": [
    {
      "id": "t001",
      "title": "March of Iron",
      "artist": "K. Halvorsen",
      "duration": 342,
      "url": "https://cdn.tabletopscore.io/audio/march-of-iron.m4a",
      "bytes": 5480000,
      "composer": "Kevin MacLeod",
      "license": "CC-BY-4.0",
      "sourceURL": "https://incompetech.com",
      "creditText": "\"March of Iron\" Kevin MacLeod (incompetech.com), CC-BY 4.0"
    }
  ],
  "games": [
    {
      "id": "scythe",
      "name": "Scythe",
      "artwork": "https://cdn.tabletopscore.io/box/scythe.jpg",
      "heroArtwork": "https://cdn.tabletopscore.io/hero/scythe.jpg",
      "players": [1, 5],
      "playTime": 115,
      "rank": 7,
      "featured": true,
      "categories": ["war", "euro", "heavy", "epic-length", "solo", "three-four", "party-five", "competitive"],
      "playlistId": "drums-of-war"
    }
  ]
}
```

`games[].playlistId` is the hand-curated soundtrack mapping (§2.1) and must
reference a playlist id in the same manifest. `artwork`/`heroArtwork` may be
`null` while box-art licensing is pending — the client renders deterministic
placeholder art (gradient + initials keyed by game id) whenever they are.

### 6.2 Caching layer (v1.1)
`URLSession` download task → save to `Application Support/AudioCache/` → set `isDownloaded`/`localFileName` on the Track → player prefers local file. LRU eviction against a user-set cache cap. AVPlayer alone already avoids re-downloading within a session via `AVURLAsset` buffering.

---

## 7. Architecture

- **Pattern:** MVVM. `@Observable` view models; SwiftData `@Query` in views for catalog lists; a single `PlayerService` (`@Observable`, injected via `.environment`) owning the AVQueuePlayer.
- **Modules:** `Catalog` (sync + SwiftData), `Player` (engine + now-playing), `Browse` (UI), `DesignSystem` (colors, cards, shimmer).
- **Networking:** async/await `URLSession`; manifest ETag/If-None-Match to skip unchanged catalogs.
- **Images:** Nuke (or AsyncImage + custom disk cache) — poster images are also remote-only.

---

## 8. Key User Flows

1. **First launch:** splash → fetch catalog (spinner + shimmer rows) → Home populated → tap hero "Play" → music in <3 s.
2. **Match my game:** Home → "War Games" row → "Drums of War" → Play → mini player persists while browsing.
3. **Session end:** long-press mini player → "Stop after 30 min" sleep timer.
4. **Offline (v1.1):** playlist detail → download icon → plays from cache without network.

---

## 9. Non-Functional Requirements

| Requirement | Target |
|---|---|
| App binary size | < 30 MB (no bundled media) |
| Time to first audio | < 3 s on LTE |
| Catalog size | ≥ 60 tracks, ≥ 12 playlists, ≥ 20 categories, ≥ 100 games at launch |
| Battery | ≤ ~5%/h during locked-screen playback |
| Accessibility | VoiceOver labels on all cards/controls, Dynamic Type, reduced-motion variant for carousels |
| Localization | v1 English; strings in String Catalogs from day one |

---

## 10. Milestones

1. **M1 (wk 1–2):** SwiftData models, catalog sync, Home browse UI with placeholder art.
2. **M2 (wk 3):** PlayerService, mini + full player, background audio, lock-screen controls.
3. **M3 (wk 4):** Search, Library, favorites, sleep timer, crossfade.
4. **M4 (wk 5):** Content — 60+ tracks uploaded, artwork, category curation; polish + TestFlight.
5. **v1.1:** offline downloads, iPad layout, HLS migration.
