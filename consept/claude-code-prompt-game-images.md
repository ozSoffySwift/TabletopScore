# Claude Code prompt — Fetch real game images and wire them into the app

Run in the TableScore project folder. Requires `fetch_game_art.py` in the folder.

---

Get real board-game box art into TableScore using the BoardGameGeek pipeline.

1. **Run the fetcher.** Execute `fetch_game_art.py` (Python 3, `pip install requests`). It queries the BGG XML API for ~100 popular games and produces `games.json` (metadata + image URLs in our catalog schema) and an `art/` folder with downloaded box art. BGG replies 202 while queueing — the script retries; be patient on first run, and don't parallelize or tighten its rate limits.

2. **Verify the output.** Check `games.json` has ~100 entries with non-null `name`, `artwork`, `players`, `playTime`. Spot-check 5 well-known entries (Gloomhaven, Catan, Wingspan, Brass: Birmingham, Scythe) — confirm each id matched the right game name. Flag any mismatches or missing images in a short report and drop those entries rather than shipping wrong art.

3. **Curate playlists.** Replace every `playlistId: "TODO-curate"` with a real playlist id from our catalog, chosen by theme (use `bggCategories` as the guide: Wargame → war playlist, Trains/Economic → 18xx or engine-builder playlist, Horror → horror, Animals/Farming → cozy, etc.). Every game must map to exactly one existing playlist; create at most 2–3 new playlists if a theme cluster has no fit.

4. **Merge into the catalog.** Fold the curated `games` array into the dev fixture `catalog.json`, bump the manifest `version`, and make catalog sync upsert them (extend the sync unit tests for games with images).

5. **Serve images locally for dev.** Don't hotlink BGG in the app at runtime. Copy `art/` into a `DevCDN/` folder and add a tiny dev-only static file server target (or use the bundled-fixture `CatalogSource` with local file URLs) so `artwork` URLs resolve offline during development. Keep the production path unchanged: real CDN URLs in the manifest later.

6. **Show it in the UI.** Game cards and the hero carousel should now render the real box art via AsyncImage with disk caching, with the existing PlaceholderArt as the loading/failure fallback. Keep 2:3 cards; letterbox non-2:3 covers with a blurred-edge fill rather than cropping the art.

7. **Attribution & licensing guardrails.** Add "Powered by BoardGameGeek" with a link in Settings → About, and a `LICENSING.md` at repo root stating: BGG API data/images are used under BGG's non-commercial API terms; a BGG commercial license (or publisher permissions) is required before any paid/ad-supported App Store release. Do not strip the `attribution` field from the manifest.

Build with `xcodebuild` after wiring the UI and fix all errors/warnings. Finish with a summary: games fetched, images downloaded, mismatches dropped, playlists assigned per category.
