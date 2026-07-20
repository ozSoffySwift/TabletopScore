# assets/

Organized, downloaded copies of the app's media. Two folders:

```
assets/
├── images/
│   ├── branding/     app icon + splash screen (copies; originals in Marketing/)
│   └── games/        game box art — EMPTY, see below
└── sound/
    └── music/        67 tracks, Kevin MacLeod (CC-BY 4.0) — canonical location
```

## sound/music/ — done

67 MP3s downloaded and verified by `Tools/fetch_music.py` (license audit
trail in `Tools/sources.csv`). This is the **canonical** location —
`DevCDN/audio` is a symlink here, so the dev server
(`Tools/serve_devcdn.sh`) and the PocketBase migration script
(`backend/migrate_content.py`) both keep working unchanged.

## images/branding/ — done

Copies of the app icon and splash screen for easy reference. **Originals
live in `Marketing/`** — `Tools/remove_splash_waves.py` reads from there, so
that folder stays the source of truth; don't edit the copies here expecting
them to propagate.

## images/games/ — done (user-supplied, 2026-07-20)

105 box-art images, one per catalog game, supplied by the developer. Naming
convention: `{Game_Name}_{category}_{year}_{WxH}.{jpg|png|webp}`.

Uploaded to the PocketBase `games.artwork` field by
`backend/upload_game_art.py`, which derives each game's catalog slug from the
filename (slugified, with an alphanumeric-only fallback so apostrophes and
accents still match — e.g. `Aeons_End` → `aeon-s-end`, `Orléans` → `orléans`).
Re-running is idempotent; `FORCE_FILES=1` re-uploads.

The catalog hook exposes these as absolute HTTPS URLs, the app syncs them, and
`ArtworkView` renders them (letterboxed with a blurred edge-fill, since most
covers are square while the poster frame is 2:3). The hero carousel falls back
to `artwork` when `heroArtwork` is empty, so only `artwork` is populated.
`PlaceholderArt` remains the fallback for any game without art.

**Licensing:** board game box art is the publishers' copyright, independent of
where the file came from. `LICENSING.md` flags this as a pre-commercial-release
item — confirm rights (or swap to commissioned/original art) before shipping an
ad-supported build. The `attribution` field on games must not be stripped.
