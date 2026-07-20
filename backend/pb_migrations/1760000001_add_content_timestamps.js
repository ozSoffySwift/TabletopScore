/// <reference path="../pb_data/types.d.ts" />
// Add `created`/`updated` autodate fields to the content collections.
//
// The catalog.json hook derives the manifest `version` from the newest
// `updated` timestamp across collections. Base collections created via the
// JS migration API do NOT get autodate fields automatically, so without this
// the version is permanently 0 — and the iOS sync is version-gated
// (`manifest.version != lastVersion`), so a 0/0 match makes a fresh install
// skip its very first sync and load no content. This backfills the fields and
// touches every existing record so `updated` is populated (non-zero version).
//
// Idempotent: skips a collection that already has an `updated` field, so it is
// a no-op on fresh deploys where 1760000000 already defines the fields.

migrate((app) => {
  for (const name of ["categories", "tracks", "playlists", "games"]) {
    const col = app.findCollectionByNameOrId(name);
    if (col.fields.find((f) => f.name === "updated")) continue;

    col.fields.add(new Field({ name: "created", type: "autodate", onCreate: true, onUpdate: false }));
    col.fields.add(new Field({ name: "updated", type: "autodate", onCreate: true, onUpdate: true }));
    app.save(col);

    // Existing rows get the zero value when the field is added — save each so
    // the onUpdate autodate fires and `updated` becomes "now".
    for (const rec of app.findAllRecords(name)) {
      app.save(rec);
    }
  }
}, (app) => {
  for (const name of ["categories", "tracks", "playlists", "games"]) {
    const col = app.findCollectionByNameOrId(name);
    for (const field of ["created", "updated"]) {
      const f = col.fields.find((x) => x.name === field);
      if (f) col.fields.removeById(f.id);
    }
    app.save(col);
  }
});
