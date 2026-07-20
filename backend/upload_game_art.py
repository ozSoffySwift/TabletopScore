#!/usr/bin/env python3
"""Upload game box art from assets/images/games/ to the PocketBase `games`
collection's `artwork` field. Idempotent: skips games that already have
artwork unless FORCE_FILES=1.

Filenames follow `{Game_Name}_{category}_{year}_{WxH}.{ext}`; the game name is
slugified and matched against the catalog slug, with an alphanumeric-only
fallback so apostrophe/accent differences still match (e.g. "Aeons End" ->
"aeon-s-end").

The hero carousel falls back to `artwork` when `heroArtwork` is empty, so only
`artwork` needs uploading.

Usage:
    PB_URL=... PB_ADMIN_EMAIL=... PB_ADMIN_PASSWORD=... \
    python3 backend/upload_game_art.py
"""
import os
import re
import sys

import requests

ROOT = os.path.join(os.path.dirname(__file__), "..")
IMG_DIR = os.path.join(ROOT, "assets", "images", "games")

PB_URL = os.environ.get("PB_URL", "").rstrip("/")
EMAIL = os.environ.get("PB_ADMIN_EMAIL")
PASSWORD = os.environ.get("PB_ADMIN_PASSWORD")
FORCE = os.environ.get("FORCE_FILES") == "1"
if not (PB_URL and EMAIL and PASSWORD):
    sys.exit("set PB_URL, PB_ADMIN_EMAIL, PB_ADMIN_PASSWORD")

EXTS = (".jpg", ".jpeg", ".png", ".webp")
MIME = {".jpg": "image/jpeg", ".jpeg": "image/jpeg",
        ".png": "image/png", ".webp": "image/webp"}
NAME_PAT = re.compile(r"^(.*?)_[a-z0-9-]+_\d{4}_\d+x\d+$", re.IGNORECASE)

session = requests.Session()


def slugify(s):
    # No NFKD — catalog slugs retain accents (e.g. "orléans").
    out = []
    for ch in s.lower():
        if ch.isalnum():
            out.append(ch)
        elif out and out[-1] != "-":
            out.append("-")
    return "".join(out).strip("-")


def compact(s):
    return "".join(c for c in s.lower() if c.isalnum())


def auth():
    r = session.post(f"{PB_URL}/api/collections/_superusers/auth-with-password",
                     json={"identity": EMAIL, "password": PASSWORD}, timeout=30)
    r.raise_for_status()
    session.headers["Authorization"] = r.json()["token"]


def all_games():
    """slug -> record, paging through the collection."""
    games, page = {}, 1
    while True:
        r = session.get(f"{PB_URL}/api/collections/games/records",
                        params={"perPage": 200, "page": page}, timeout=60)
        r.raise_for_status()
        data = r.json()
        for rec in data["items"]:
            games[rec["slug"]] = rec
        if page >= data["totalPages"]:
            break
        page += 1
    return games


def main():
    auth()
    games = all_games()
    compact_index = {}
    for slug in games:
        compact_index.setdefault(compact(slug), slug)

    files = sorted(f for f in os.listdir(IMG_DIR)
                   if os.path.splitext(f)[1].lower() in EXTS)
    uploaded = skipped = 0
    unmatched = []

    for f in files:
        stem, ext = os.path.splitext(f)
        m = NAME_PAT.match(stem)
        name = m.group(1).replace("_", " ") if m else stem
        slug = slugify(name)
        if slug not in games:
            slug = compact_index.get(compact(slug))
        if not slug:
            unmatched.append(f)
            continue

        rec = games[slug]
        if rec.get("artwork") and not FORCE:
            skipped += 1
            continue

        path = os.path.join(IMG_DIR, f)
        with open(path, "rb") as fh:
            r = session.patch(
                f"{PB_URL}/api/collections/games/records/{rec['id']}",
                files={"artwork": (f, fh, MIME[ext.lower()])}, timeout=300)
        if not r.ok:
            sys.exit(f"{slug} ({f}): {r.status_code} {r.text[:300]}")
        uploaded += 1
        print(f"  {slug} <- {f} ({os.path.getsize(path)//1024} KB)")

    print(f"\nuploaded {uploaded}, skipped (already had art) {skipped}, "
          f"unmatched {len(unmatched)}")
    for f in unmatched:
        print(f"  UNMATCHED: {f}")


if __name__ == "__main__":
    main()
