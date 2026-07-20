#!/usr/bin/env python3
"""Fetch Kevin MacLeod classical / public-domain arrangements from incompetech
(CC-BY 4.0 — commercial/ad-supported use permitted with attribution) for the
app's "Classical" playlist.

Same verification contract as fetch_music.py: a candidate ships only if its
incompetech URL returns HTTP 200, MP3 magic bytes (ID3 or MPEG frame-sync),
and a plausible size. Unverifiable titles are reported and skipped.

Writes verified MP3s to assets/sound/music/ (the canonical audio dir;
DevCDN/audio symlinks to it), emits Tools/classical_manifest.json with track
metadata, and appends license-audit rows to Tools/sources.csv.
"""
import csv
import datetime
import json
import os
import time
from urllib.parse import quote

import requests

ROOT = os.path.join(os.path.dirname(__file__), "..")
AUDIO_DIR = os.path.join(ROOT, "assets", "sound", "music")
OUT = os.path.join(os.path.dirname(__file__), "classical_manifest.json")
SOURCES = os.path.join(os.path.dirname(__file__), "sources.csv")

BASE = "https://incompetech.com/music/royalty-free/mp3-royaltyfree/{}.mp3"
SOURCE_PAGE = "https://incompetech.com/music/royalty-free/"
HEADERS = {"User-Agent": "TableScore-catalog-builder/1.0 (dev tooling)"}

# Candidate KM titles that are arrangements of public-domain classical works
# (or KM classical-style piano originals). Reality is enforced by verification;
# generous list, keep what verifies. Titles already downloaded are reused.
CANDIDATES = [
    # Pachelbel / Bach / Beethoven / Satie (already in catalog — reused)
    "Canon in D Major", "Prelude in C - BWV 846", "Egmont Overture Finale",
    "Gymnopedie No 1", "Meditation Impromptu 01", "Meditation Impromptu 02",
    "Divertissement",
    # Bach
    "Fugue in D Minor", "Brandenburg No4", "Air Prelude",
    # Grieg
    "In the Hall of the Mountain King",
    # Saint-Saens — Danse Macabre variants
    "Danse Macabre - Finale", "Danse Macabre - Busy Ending",
    "Danse Macabre - Low Strings", "Danse Macabre - Sad Part",
    "Danse Macabre - Violin Hook", "Danse Macabre - No Violin",
    # Joplin ragtime (public domain)
    "The Entertainer", "Maple Leaf Rag",
    # Tchaikovsky — Nutcracker
    "Dance of the Sugar Plum Fairy", "Waltz of the Flowers",
    "Russian Dance - Trepak", "Arabian Dance", "Chinese Dance",
    "March of the Nutcracker", "Nutcracker Overture",
    # KM classical-style piano / strings
    "String Impromptu Number 1", "Frost Waltz", "Angevin",
    "Suonatore di Liuto", "Sonatina", "Sonata",
    # Long-shots (verify or drop)
    "Fur Elise", "Moonlight Sonata", "Clair de Lune",
    "William Tell Overture", "Wedding March", "Ode to Joy",
]


def slugify(name):
    out = []
    for ch in name.lower():
        if ch.isalnum():
            out.append(ch)
        elif out and out[-1] != "-":
            out.append("-")
    return "".join(out).strip("-")


def main():
    os.makedirs(AUDIO_DIR, exist_ok=True)
    today = datetime.date.today().isoformat()
    verified, skipped, audit_rows = [], [], []

    for title in CANDIDATES:
        filename = f"{title}.mp3"
        dest = os.path.join(AUDIO_DIR, filename)
        url = BASE.format(quote(title))

        if not os.path.exists(dest):
            try:
                r = requests.get(url, headers=HEADERS, timeout=90)
            except requests.RequestException as e:
                skipped.append((title, f"request error: {e}"))
                continue
            looks_like_mp3 = r.content[:3] == b"ID3" or (
                len(r.content) > 2 and r.content[0] == 0xFF and (r.content[1] & 0xE0) == 0xE0
            )
            if r.status_code != 200 or len(r.content) < 400_000 or not looks_like_mp3:
                skipped.append((title, f"{r.status_code} {len(r.content)}b mp3={looks_like_mp3}"))
                time.sleep(1)
                continue
            with open(dest, "wb") as f:
                f.write(r.content)
            print(f"  downloaded {title} ({len(r.content)//1024} KB)")
            time.sleep(1)
        else:
            print(f"  reuse {title} (already present)")

        size = os.path.getsize(dest)
        track_id = f"km-{slugify(title)}"
        verified.append({
            "id": track_id,
            "title": title,
            "artist": "Kevin MacLeod",
            "duration": round(size * 8 / 192_000),  # estimate; AVPlayer reads real
            "filename": filename,
            "bytes": size,
            "composer": "Kevin MacLeod",
            "license": "CC-BY-4.0",
            "sourceURL": SOURCE_PAGE,
            "creditText": f"“{title}” Kevin MacLeod (incompetech.com), Licensed under Creative Commons: By Attribution 4.0",
        })
        audit_rows.append([track_id, title, "Kevin MacLeod", "incompetech", url,
                           "CC-BY-4.0", today, "classical playlist; ads-safe with attribution"])

    with open(OUT, "w") as f:
        json.dump(verified, f, indent=2, ensure_ascii=False)
    # Only append audit rows for tracks not already in sources.csv.
    existing_ids = set()
    if os.path.exists(SOURCES):
        with open(SOURCES) as f:
            for row in csv.reader(f):
                if row:
                    existing_ids.add(row[0])
    new_rows = [r for r in audit_rows if r[0] not in existing_ids]
    with open(SOURCES, "a", newline="") as f:
        csv.writer(f).writerows(new_rows)

    print(f"\nverified {len(verified)} classical tracks "
          f"({len(new_rows)} new audit rows)")
    if skipped:
        print("skipped (not verified — NOT shipped):")
        for title, why in skipped:
            print(f"  {title} — {why}")


if __name__ == "__main__":
    main()
