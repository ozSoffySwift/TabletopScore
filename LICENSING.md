# Licensing notes

## BoardGameGeek data & box art

Game metadata (names, player counts, play times, rankings, categories) and
box-art images in the development catalog were fetched from the
[BoardGameGeek XML API](https://boardgamegeek.com/wiki/page/BGG_XML_API2)
by `consept/fetch_game_art.py`.

- **Terms:** BGG's API terms permit **non-commercial** use with attribution
  ("Powered by BoardGameGeek"). The app shows this attribution in
  Settings → About, and every fetched game in the catalog manifest carries an
  `attribution` field — **do not strip it**.
- **Before any commercial release** (paid, ad-supported, or IAP on the App
  Store), you must either obtain a commercial license from BoardGameGeek
  (licensing@boardgamegeek.com) **or** replace the BGG-sourced images and
  data with content you have rights to.
- **Box-art copyright belongs to the game publishers**, not BGG. A BGG API
  license covers the data/API usage; publisher permission (or a service that
  licenses cover imagery) may additionally be required for storefront use of
  box art. Commission original genre artwork if in doubt (spec §3).

## Music

The development catalog streams Kevin MacLeod (incompetech) tracks under
CC-BY 4.0 — commercial/ad-supported use is permitted with the credit lines
shown in Settings → Music Credits. Files are served from the local `DevCDN/`
during development (`Tools/serve_devcdn.sh`) and move to the production CDN
unchanged. `Tools/fetch_music.py` is the download/verification script.

### Approved production sources (research 2026-07)

**The app will carry ads (commercial use).** Only sources whose licenses
permit commercial/ad-supported apps are approved. Anything licensed
non-commercial (CC-BY-NC in any variant) is banned outright — do not add
NC-licensed tracks "temporarily".

| Source | License | Attribution | Notes |
|---|---|---|---|
| Pixabay Music | Pixabay Content License | none required | commercial OK; never offer tracks as standalone downloads |
| Kevin MacLeod (incompetech) | CC-BY 4.0 | required | credit in Music Credits screen; $ per-track buyout available |
| Scott Buckley | CC-BY 4.0 | required | cinematic/epic playlists |
| Alexander Nakarada | CC-BY 4.0 | required | celtic/medieval/fantasy |
| Musopen | PD / per-recording CC | check each recording | composition PD ≠ recording PD; skip NC-licensed recordings |

**Avoid:** any CC-BY-NC/NC-ND source (incompatible with ads), YouTube Audio
Library (YouTube-only license), Jamendo (paid commercial license),
Epidemic/Artlist (subscription doesn't cover in-app redistribution).

### Compliance rules baked into the app

1. Every track in `catalog.json` carries `composer`, `license`, `sourceURL`,
   and `creditText`. Sync stores them; **Settings → Music Credits** lists
   every credit line grouped by composer — this satisfies CC-BY for apps.
   Do not remove that screen while any CC-BY track ships.
2. `Tools/sources.csv` is the audit trail: one row per downloaded track
   (source URL, license, download date). Keep it current.
3. Re-encoding to AAC, trimming, and loudness-normalizing (~-16 LUFS) is
   permitted for all approved sources above.
4. Never expose raw track downloads to users (Pixabay's "no standalone
   redistribution" clause; also keeps CC-BY simple). The v1.1 offline cache
   must stay an internal cache, not a file export.

## Splash / app icon

`Marketing/` artwork is original work owned by the developer (Oz Soffy).
