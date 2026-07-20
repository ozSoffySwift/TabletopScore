#!/usr/bin/env python3
"""Migrate the dev fixture into PocketBase (Phase 3.2). Idempotent: records
are upserted by their `slug`, so re-runs update rather than duplicate.

Usage:
    PB_URL=https://your-domain \
    PB_ADMIN_EMAIL=... PB_ADMIN_PASSWORD=... \
    python3 backend/migrate_content.py

Credentials come from env vars only — never hardcode or commit them.
Media: track MP3s from DevCDN/audio/, game box art from DevCDN/art/ (if
present). Files upload once; pass FORCE_FILES=1 to re-upload.
"""
import json
import os
import sys
from urllib.parse import unquote, urlparse

import requests

ROOT = os.path.join(os.path.dirname(__file__), "..")
CATALOG = os.path.join(ROOT, "TabletopScore", "Resources", "catalog.json")
AUDIO_DIR = os.path.join(ROOT, "DevCDN", "audio")
ART_DIR = os.path.join(ROOT, "DevCDN", "art")

PB_URL = os.environ.get("PB_URL", "").rstrip("/")
EMAIL = os.environ.get("PB_ADMIN_EMAIL")
PASSWORD = os.environ.get("PB_ADMIN_PASSWORD")
FORCE_FILES = os.environ.get("FORCE_FILES") == "1"
if not (PB_URL and EMAIL and PASSWORD):
    sys.exit("set PB_URL, PB_ADMIN_EMAIL, PB_ADMIN_PASSWORD")

session = requests.Session()


def auth():
    r = session.post(f"{PB_URL}/api/collections/_superusers/auth-with-password",
                     json={"identity": EMAIL, "password": PASSWORD}, timeout=30)
    r.raise_for_status()
    session.headers["Authorization"] = r.json()["token"]


def find(collection, slug):
    r = session.get(f"{PB_URL}/api/collections/{collection}/records",
                    params={"filter": f"slug='{slug}'", "perPage": 1}, timeout=30)
    r.raise_for_status()
    items = r.json()["items"]
    return items[0] if items else None


def upsert(collection, slug, fields, files=None):
    existing = find(collection, slug)
    payload = {"slug": slug, **fields}
    send_files = {}
    if files:
        for field, path in files.items():
            already = existing and existing.get(field)
            if path and os.path.exists(path) and (FORCE_FILES or not already):
                send_files[field] = (os.path.basename(path), open(path, "rb"))
    # multipart when uploading files, JSON otherwise
    if existing:
        url = f"{PB_URL}/api/collections/{collection}/records/{existing['id']}"
        r = (session.patch(url, data=_form(payload), files=send_files, timeout=300)
             if send_files else session.patch(url, json=payload, timeout=60))
    else:
        url = f"{PB_URL}/api/collections/{collection}/records"
        r = (session.post(url, data=_form(payload), files=send_files, timeout=300)
             if send_files else session.post(url, json=payload, timeout=60))
    for f in send_files.values():
        f[1].close()
    if not r.ok:
        sys.exit(f"{collection}/{slug}: {r.status_code} {r.text}")
    return r.json()


def _form(payload):
    # requests encodes list values as repeated fields, which PocketBase
    # accepts for multi-relation fields.
    return {k: v for k, v in payload.items() if v is not None}


def main():
    auth()
    with open(CATALOG) as f:
        manifest = json.load(f)

    print("== categories ==")
    category_ids = {}
    for c in manifest["categories"]:
        rec = upsert("categories", c["id"], {
            "name": c["name"], "group": c["group"], "sortIndex": c["sortIndex"],
        })
        category_ids[c["id"]] = rec["id"]
    print(f"  {len(category_ids)} upserted")

    print("== tracks (uploads audio on first run — this takes a while) ==")
    track_ids = {}
    for t in manifest["tracks"]:
        audio_file = os.path.join(AUDIO_DIR, unquote(os.path.basename(urlparse(t["url"]).path)))
        rec = upsert("tracks", t["id"], {
            "title": t["title"], "artist": t["artist"], "duration": t["duration"],
            "bytes": t.get("bytes"), "composer": t.get("composer"),
            "license": t.get("license"), "sourceURL": t.get("sourceURL"),
            "creditText": t.get("creditText"),
        }, files={"audio": audio_file})
        track_ids[t["id"]] = rec["id"]
        print(f"  {t['id']}")

    print("== playlists ==")
    playlist_ids = {}
    for p in manifest["playlists"]:
        rec = upsert("playlists", p["id"], {
            "name": p["name"], "summary": p["summary"],
            "featured": p.get("featured", False), "sortIndex": p.get("sortIndex", 0),
            "categories": [category_ids[c] for c in p["categories"]],
            "tracks": [track_ids[t] for t in p["trackIds"]],
        })
        playlist_ids[p["id"]] = rec["id"]
    print(f"  {len(playlist_ids)} upserted")

    print("== games ==")
    for g in manifest.get("games", []):
        art_file = os.path.join(ART_DIR, f"{g['id']}.jpg")
        upsert("games", g["id"], {
            "name": g["name"],
            "playersMin": g["players"][0], "playersMax": g["players"][1],
            "playTime": g["playTime"], "rank": g.get("rank"),
            "featured": g.get("featured", False),
            "categories": [category_ids[c] for c in g["categories"]],
            "playlist": playlist_ids[g["playlistId"]],
            "attribution": g.get("attribution"),
        }, files={"artwork": art_file})
    print(f"  {len(manifest.get('games', []))} upserted")

    r = session.get(f"{PB_URL}/api/catalog.json", timeout=60)
    print(f"\ncatalog.json endpoint: {r.status_code}, "
          f"version {r.json().get('version') if r.ok else '?'}, "
          f"{len(r.json().get('tracks', [])) if r.ok else 0} tracks")


if __name__ == "__main__":
    main()
