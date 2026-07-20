#!/usr/bin/env python3
"""Add the Classical category + playlist to PocketBase. Idempotent (upsert by
slug). New tracks upload their MP3 from assets/sound/music/; existing tracks
are resolved by slug. Run after Tools/fetch_classical.py.

Usage:
    PB_URL=... PB_ADMIN_EMAIL=... PB_ADMIN_PASSWORD=... \
    python3 backend/add_classical.py
"""
import json
import os
import sys

import requests

ROOT = os.path.join(os.path.dirname(__file__), "..")
AUDIO_DIR = os.path.join(ROOT, "assets", "sound", "music")
MANIFEST = os.path.join(ROOT, "Tools", "classical_manifest.json")

PB_URL = os.environ.get("PB_URL", "").rstrip("/")
EMAIL = os.environ.get("PB_ADMIN_EMAIL")
PASSWORD = os.environ.get("PB_ADMIN_PASSWORD")
if not (PB_URL and EMAIL and PASSWORD):
    sys.exit("set PB_URL, PB_ADMIN_EMAIL, PB_ADMIN_PASSWORD")

# Curated Classical playlist: distinct, full-length classical works, in play
# order (calm opener -> dramatic closer). Public-domain compositions arranged
# by Kevin MacLeod (CC-BY 4.0) plus his classical-style piano/string originals.
PLAYLIST_ORDER = [
    "km-canon-in-d-major",           # Pachelbel
    "km-air-prelude",                # Bach
    "km-prelude-in-c-bwv-846",       # Bach
    "km-gymnopedie-no-1",            # Satie
    "km-meditation-impromptu-01",    # MacLeod
    "km-meditation-impromptu-02",    # MacLeod
    "km-divertissement",             # MacLeod
    "km-sonatina",                   # MacLeod
    "km-string-impromptu-number-1",  # MacLeod
    "km-frost-waltz",                # MacLeod
    "km-dance-of-the-sugar-plum-fairy",  # Tchaikovsky
    "km-the-entertainer",            # Joplin
    "km-maple-leaf-rag",             # Joplin
    "km-egmont-overture-finale",     # Beethoven
    "km-danse-macabre-no-violin",    # Saint-Saens
]

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


def main():
    auth()
    manifest = {t["id"]: t for t in json.load(open(MANIFEST))}

    # --- Classical category (genre group, after the existing 8 genres) --------
    cat = find("categories", "classical")
    cat_payload = {"slug": "classical", "name": "Classical", "group": "genre", "sortIndex": 9}
    if cat:
        session.patch(f"{PB_URL}/api/collections/categories/records/{cat['id']}", json=cat_payload, timeout=30).raise_for_status()
        cat_id = cat["id"]
    else:
        r = session.post(f"{PB_URL}/api/collections/categories/records", json=cat_payload, timeout=30)
        r.raise_for_status(); cat_id = r.json()["id"]
    print(f"category classical -> {cat_id}")

    # --- Tracks: resolve existing by slug, upload the new ones -----------------
    track_ids = []
    for slug in PLAYLIST_ORDER:
        existing = find("tracks", slug)
        if existing:
            track_ids.append(existing["id"])
            continue
        meta = manifest.get(slug)
        if not meta:
            sys.exit(f"track {slug} not on server and not in classical_manifest.json")
        path = os.path.join(AUDIO_DIR, meta["filename"])
        if not os.path.exists(path):
            sys.exit(f"missing audio file: {path}")
        data = {"slug": slug, "title": meta["title"], "artist": meta["artist"],
                "duration": meta["duration"], "bytes": meta["bytes"],
                "composer": meta["composer"], "license": meta["license"],
                "sourceURL": meta["sourceURL"], "creditText": meta["creditText"]}
        with open(path, "rb") as fh:
            r = session.post(f"{PB_URL}/api/collections/tracks/records",
                             data=data, files={"audio": (meta["filename"], fh)}, timeout=300)
        if not r.ok:
            sys.exit(f"track {slug}: {r.status_code} {r.text}")
        track_ids.append(r.json()["id"])
        print(f"  uploaded {slug}")

    # --- Classical playlist ----------------------------------------------------
    pl = find("playlists", "classical")
    pl_payload = {
        "slug": "classical", "name": "Classical",
        "summary": "Timeless classical pieces — Pachelbel, Bach, Satie, Tchaikovsky, Joplin and more — for focused, elegant play.",
        "featured": True, "sortIndex": 17,
        "categories": [cat_id], "tracks": track_ids,
    }
    if pl:
        session.patch(f"{PB_URL}/api/collections/playlists/records/{pl['id']}", json=pl_payload, timeout=60).raise_for_status()
        print(f"playlist classical updated ({len(track_ids)} tracks)")
    else:
        r = session.post(f"{PB_URL}/api/collections/playlists/records", json=pl_payload, timeout=60)
        r.raise_for_status()
        print(f"playlist classical created ({len(track_ids)} tracks)")


if __name__ == "__main__":
    main()
