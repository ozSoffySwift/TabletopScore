/// <reference path="../pb_data/types.d.ts" />
// GET /api/catalog.json — renders the manifest format the iOS app already
// parses (spec §6.1), with slugs as ids and media URLs pointing at
// PocketBase's file endpoints. ETag + 5-minute cache.
//
// `version` derives from the newest `updated` timestamp across content
// collections, so any admin edit bumps it and clients resync.

routerAdd("GET", "/api/catalog.json", (e) => {
  const fileURL = (rec, field) => {
    const name = rec.getString(field);
    if (!name) return null;
    return "/api/files/" + rec.collection().name + "/" + rec.id + "/" + name;
  };

  let newest = 0;
  const all = {};
  for (const col of ["categories", "tracks", "playlists", "games"]) {
    all[col] = $app.findAllRecords(col);
    for (const rec of all[col]) {
      const u = rec.getDateTime("updated").unix();
      if (u > newest) newest = u;
    }
  }
  const version = newest;

  const ifNoneMatch = e.request.header.get("If-None-Match");
  const etag = '"' + version + '"';
  e.response.header().set("ETag", etag);
  e.response.header().set("Cache-Control", "public, max-age=300");
  if (ifNoneMatch === etag) {
    return e.noContent(304);
  }

  // slug lookup for relations
  const slugOf = {};
  for (const col of ["categories", "tracks", "playlists"]) {
    for (const rec of all[col]) slugOf[rec.id] = rec.getString("slug");
  }

  const manifest = {
    version: version,
    updatedAt: new Date(newest * 1000).toISOString().replace(/\.\d+Z$/, "Z"),
    categories: all.categories.map((r) => ({
      id: r.getString("slug"),
      name: r.getString("name"),
      group: r.getString("group"),
      sortIndex: r.getInt("sortIndex"),
    })),
    playlists: all.playlists.map((r) => ({
      id: r.getString("slug"),
      name: r.getString("name"),
      summary: r.getString("summary"),
      artwork: fileURL(r, "artwork"),
      heroArtwork: fileURL(r, "heroArtwork"),
      featured: r.getBool("featured"),
      sortIndex: r.getInt("sortIndex"),
      categories: r.getStringSlice("categories").map((id) => slugOf[id]).filter(Boolean),
      trackIds: r.getStringSlice("tracks").map((id) => slugOf[id]).filter(Boolean),
    })),
    tracks: all.tracks.map((r) => ({
      id: r.getString("slug"),
      title: r.getString("title"),
      artist: r.getString("artist"),
      duration: r.getInt("duration"),
      url: fileURL(r, "audio"),
      bytes: r.getInt("bytes"),
      composer: r.getString("composer") || null,
      license: r.getString("license") || null,
      sourceURL: r.getString("sourceURL") || null,
      creditText: r.getString("creditText") || null,
    })),
    games: all.games.map((r) => ({
      id: r.getString("slug"),
      name: r.getString("name"),
      artwork: fileURL(r, "artwork"),
      heroArtwork: fileURL(r, "heroArtwork"),
      players: [r.getInt("playersMin"), r.getInt("playersMax")],
      playTime: r.getInt("playTime"),
      rank: r.getInt("rank"),
      featured: r.getBool("featured"),
      categories: r.getStringSlice("categories").map((id) => slugOf[id]).filter(Boolean),
      playlistId: slugOf[r.getStringSlice("playlist")[0]] || "",
      attribution: r.getString("attribution") || null,
    })),
  };

  // Media URLs must be absolute for AVPlayer/AsyncImage.
  const base = "https://" + e.request.host;
  const absolutize = (o, keys) => keys.forEach((k) => { if (o[k]) o[k] = base + o[k]; });
  manifest.playlists.forEach((p) => absolutize(p, ["artwork", "heroArtwork"]));
  manifest.tracks.forEach((t) => absolutize(t, ["url"]));
  manifest.games.forEach((g) => absolutize(g, ["artwork", "heroArtwork"]));

  return e.json(200, manifest);
});

// GET /api/stats/summary — admin-only usage dashboard from `events`.
routerAdd("GET", "/api/stats/summary", (e) => {
  const q = (sql) => {
    const rows = arrayOf(new DynamicModel({ k: "", n: 0 }));
    $app.db().newQuery(sql).all(rows);
    return rows.map((r) => ({ key: r.k, count: r.n }));
  };
  return e.json(200, {
    playsPerDay: q(`SELECT date(created) AS k, COUNT(*) AS n FROM events
                    WHERE type = 'play_started' AND created > datetime('now', '-30 days')
                    GROUP BY date(created) ORDER BY k`),
    topGames: q(`SELECT gameId AS k, COUNT(*) AS n FROM events
                 WHERE type = 'game_opened' AND gameId != ''
                 GROUP BY gameId ORDER BY n DESC LIMIT 10`),
    topPlaylists: q(`SELECT playlistId AS k, COUNT(*) AS n FROM events
                     WHERE type = 'play_started' AND playlistId != ''
                     GROUP BY playlistId ORDER BY n DESC LIMIT 10`),
    uniqueDevices: q(`SELECT 'all' AS k, COUNT(DISTINCT anonDeviceId) AS n FROM events`),
  });
}, $apis.requireSuperuserAuth());
