/// <reference path="../pb_data/types.d.ts" />
// TableScore schema (PocketBase >= 0.23 JS migration API; pinned version in
// setup_server.sh). Content collections are public-read / admin-write;
// `events` is public CREATE-only (anonymous analytics), admin-read.
//
// `slug` fields carry the app's stable string ids ("drums-of-war",
// "km-five-armies", "bgg-169786") — the catalog hook exposes slugs as ids so
// the iOS sync's diffing keeps working unchanged.

migrate((app) => {
  const publicRead = { listRule: "", viewRule: "", createRule: null, updateRule: null, deleteRule: null };
  // Autodate timestamps on every content collection — the catalog.json hook
  // derives the manifest `version` from the newest `updated`, so these must
  // exist or the version is stuck at 0 (see 1760000001_add_content_timestamps).
  const stamps = () => [
    { name: "created", type: "autodate", onCreate: true, onUpdate: false },
    { name: "updated", type: "autodate", onCreate: true, onUpdate: true },
  ];

  // --- categories -----------------------------------------------------------
  const categories = new Collection({
    type: "base",
    name: "categories",
    ...publicRead,
    fields: [
      { name: "slug", type: "text", required: true },
      { name: "name", type: "text", required: true },
      { name: "group", type: "text", required: true },
      { name: "sortIndex", type: "number" },
      ...stamps(),
    ],
    indexes: ["CREATE UNIQUE INDEX idx_categories_slug ON categories (slug)"],
  });
  app.save(categories);

  // --- tracks ---------------------------------------------------------------
  const tracks = new Collection({
    type: "base",
    name: "tracks",
    ...publicRead,
    fields: [
      { name: "slug", type: "text", required: true },
      { name: "title", type: "text", required: true },
      { name: "artist", type: "text" },
      { name: "duration", type: "number" },
      { name: "audio", type: "file", maxSelect: 1, maxSize: 104857600,
        mimeTypes: ["audio/mpeg", "audio/mp4", "audio/x-m4a", "audio/aac"] },
      { name: "bytes", type: "number" },
      // License audit trail — mirrors the manifest fields (LICENSING.md).
      { name: "composer", type: "text" },
      { name: "license", type: "text" },
      { name: "sourceURL", type: "url" },
      { name: "creditText", type: "text" },
      ...stamps(),
    ],
    indexes: ["CREATE UNIQUE INDEX idx_tracks_slug ON tracks (slug)"],
  });
  app.save(tracks);

  // --- playlists --------------------------------------------------------------
  const playlists = new Collection({
    type: "base",
    name: "playlists",
    ...publicRead,
    fields: [
      { name: "slug", type: "text", required: true },
      { name: "name", type: "text", required: true },
      { name: "summary", type: "text" },
      { name: "artwork", type: "file", maxSelect: 1, maxSize: 10485760,
        mimeTypes: ["image/jpeg", "image/png", "image/webp"] },
      { name: "heroArtwork", type: "file", maxSelect: 1, maxSize: 10485760,
        mimeTypes: ["image/jpeg", "image/png", "image/webp"] },
      { name: "featured", type: "bool" },
      { name: "sortIndex", type: "number" },
      { name: "categories", type: "relation", collectionId: categories.id, maxSelect: 99 },
      // Relation order is preserved -> this IS the playlist's track order.
      { name: "tracks", type: "relation", collectionId: tracks.id, maxSelect: 999 },
      ...stamps(),
    ],
    indexes: ["CREATE UNIQUE INDEX idx_playlists_slug ON playlists (slug)"],
  });
  app.save(playlists);

  // --- games ------------------------------------------------------------------
  const games = new Collection({
    type: "base",
    name: "games",
    ...publicRead,
    fields: [
      { name: "slug", type: "text", required: true },
      { name: "name", type: "text", required: true },
      { name: "artwork", type: "file", maxSelect: 1, maxSize: 10485760,
        mimeTypes: ["image/jpeg", "image/png", "image/webp"] },
      { name: "heroArtwork", type: "file", maxSelect: 1, maxSize: 10485760,
        mimeTypes: ["image/jpeg", "image/png", "image/webp"] },
      { name: "playersMin", type: "number" },
      { name: "playersMax", type: "number" },
      { name: "playTime", type: "number" },
      { name: "rank", type: "number" },
      { name: "featured", type: "bool" },
      { name: "categories", type: "relation", collectionId: categories.id, maxSelect: 99 },
      // Exactly one curated soundtrack per game (spec §2.1).
      { name: "playlist", type: "relation", collectionId: playlists.id, maxSelect: 1 },
      // BGG attribution — never strip (LICENSING.md).
      { name: "attribution", type: "text" },
      ...stamps(),
    ],
    indexes: ["CREATE UNIQUE INDEX idx_games_slug ON games (slug)"],
  });
  app.save(games);

  // --- events: anonymous analytics, public create-only ------------------------
  const events = new Collection({
    type: "base",
    name: "events",
    listRule: null,      // admin only
    viewRule: null,      // admin only
    createRule: "",      // anyone may append
    updateRule: null,
    deleteRule: null,
    fields: [
      { name: "type", type: "text", required: true },
      { name: "trackId", type: "text" },
      { name: "gameId", type: "text" },
      { name: "playlistId", type: "text" },
      { name: "anonDeviceId", type: "text", required: true },
      { name: "ts", type: "date" },
      { name: "created", type: "autodate", onCreate: true },
    ],
  });
  app.save(events);
}, (app) => {
  for (const name of ["events", "games", "playlists", "tracks", "categories"]) {
    try { app.delete(app.findCollectionByNameOrId(name)); } catch {}
  }
});
