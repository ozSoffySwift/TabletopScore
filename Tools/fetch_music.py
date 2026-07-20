#!/usr/bin/env python3
"""Download the dev music catalog from incompetech (Kevin MacLeod, CC-BY 4.0
— commercial use incl. ad-supported apps is permitted with attribution).

For each playlist, tries candidate track titles in order (incompetech's MP3
URLs follow a stable pattern) and keeps the first TRACKS_PER_PLAYLIST that
verify (HTTP 200, audio content-type, plausible size). Unverifiable titles
are skipped and reported — nothing unverified ships.

Writes:
  DevCDN/audio/<Title>.mp3          (original filenames, per LICENSING.md)
  Tools/music_manifest.json         (consumed by Tools/gen_catalog.py)
  appends rows to Tools/sources.csv (license audit trail)
"""
import csv
import datetime
import json
import os
import re
import time
from urllib.parse import quote

import requests

ROOT = os.path.join(os.path.dirname(__file__), "..")
AUDIO_DIR = os.path.join(ROOT, "DevCDN", "audio")
MANIFEST = os.path.join(os.path.dirname(__file__), "music_manifest.json")
SOURCES = os.path.join(os.path.dirname(__file__), "sources.csv")

BASE = "https://incompetech.com/music/royalty-free/mp3-royaltyfree/{}.mp3"
SOURCE_PAGE = "https://incompetech.com/music/royalty-free/"
DEV_CDN = "http://localhost:8787/audio"
HEADERS = {"User-Agent": "TabletopScore-catalog-builder/1.0 (dev tooling)"}
TRACKS_PER_PLAYLIST = 4

# Candidate incompetech titles per playlist, best fit first. Extra candidates
# absorb 404s; the first TRACKS_PER_PLAYLIST that verify win.
CANDIDATES = {
    "drums-of-war": ["Five Armies", "Prelude and Action", "Volatile Reaction", "The Complex", "Crusade", "Grim League", "Stormfront"],
    "iron-rails": ["Deliberate Thought", "Thinking Music", "Cipher", "Bass Walker", "Off to Osaka", "George Street Shuffle"],
    "meeple-meadows": ["Thatched Villagers", "Pippin the Hunchback", "Folk Round", "Angevin", "Village Consort", "Minstrel Guild"],
    "candlelit-crypts": ["Curse of the Scarab", "The Descent", "Lord of the Land", "Skye Cuillin", "Teller of the Tales", "Rites"],
    "eldritch-static": ["Ghost Story", "House of Leaves", "Oppressive Gloom", "Anguish", "The Dread", "Come Play with Me", "Penumbra"],
    "starlane-drift": ["Space Jazz", "Martian Cowboy", "Floating Cities", "Frozen Star", "Lightless Dawn", "Deep Haze"],
    "tavern-tales": ["Master of the Feast", "Suonatore di Liuto", "Celtic Impulse", "Achaidh Cheide", "Errigal", "Salty Ditty", "Fiddles McGinty"],
    "quick-draw": ["Monkeys Spinning Monkeys", "Fluffing a Duck", "Cheery Monday", "Carefree", "Life of Riley", "Sneaky Snitch"],
    "duel-at-dawn": ["Covert Affair", "Deadly Roulette", "Hard Boiled", "I Knew a Guy", "Spy Glass", "The Chamber"],
    "solo-night": ["Gymnopedie No 1", "Meditation Impromptu 01", "Frost Waltz", "Wisps of Whorls", "Immersed", "Dreams Become Real"],
    "kindled-fellowship": ["Heroic Age", "Inspired", "Ascending the Vale", "Bathed in the Light", "Morning Snowflake", "Rising Game"],
    "shuffle-and-spark": ["Electrodoodle", "Pamgaea", "Cut and Run", "The Builder", "Overworld", "Arcadia"],
    "glass-lines": ["Meditation Impromptu 02", "Tranquility", "Study and Relax", "Wallpaper", "Divertissement", "Peace of Mind"],
    "banner-clash": ["Exhilarate", "Rhinoceros", "Take a Chance", "The Cannery", "Digya", "Happy Bee"],
    "steam-steel": ["Canon in D Major", "Fugue in D Minor", "Prelude in C - BWV 846", "Egmont Overture Finale", "Court and Page", "Brandenburg No4"],
    "engine-room": ["Local Forecast - Elevator", "Local Forecast", "Backed Vibes Clean", "Cool Vibes", "Airport Lounge", "Elevator Ride"],
    "cozy-meadow": ["Fireflies and Stardust", "Wholesome", "Garden Music", "Porch Swing Days - faster", "Front Porch Blues", "Windswept"],
}


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
    manifest = {}
    skipped = []
    claimed = set()
    today = datetime.date.today().isoformat()
    audit_rows = []

    for playlist_id, titles in CANDIDATES.items():
        tracks = []
        for title in titles:
            if len(tracks) >= TRACKS_PER_PLAYLIST:
                break
            if title in claimed:
                continue
            filename = f"{title}.mp3"
            dest = os.path.join(AUDIO_DIR, filename)
            url = BASE.format(quote(title))
            if not os.path.exists(dest):
                try:
                    r = requests.get(url, headers=HEADERS, timeout=60)
                except requests.RequestException as e:
                    skipped.append((playlist_id, title, f"request error: {e}"))
                    continue
                # incompetech serves MP3s as application/octet-stream, so
                # verify by content: ID3 tag or an MPEG frame-sync header.
                looks_like_mp3 = r.content[:3] == b"ID3" or (
                    len(r.content) > 2 and r.content[0] == 0xFF and (r.content[1] & 0xE0) == 0xE0
                )
                if r.status_code != 200 or len(r.content) < 400_000 or not looks_like_mp3:
                    skipped.append((playlist_id, title, f"{r.status_code} {len(r.content)}b mp3={looks_like_mp3}"))
                    time.sleep(1)
                    continue
                with open(dest, "wb") as f:
                    f.write(r.content)
                time.sleep(1)
            size = os.path.getsize(dest)
            claimed.add(title)
            tracks.append({
                "id": f"km-{slugify(title)}",
                "title": title,
                "artist": "Kevin MacLeod",
                "duration": round(size * 8 / 192_000),  # estimate; AVPlayer reads the real one
                "url": f"{DEV_CDN}/{quote(filename)}",
                "bytes": size,
                "composer": "Kevin MacLeod",
                "license": "CC-BY-4.0",
                "sourceURL": SOURCE_PAGE,
                "creditText": f"“{title}” Kevin MacLeod (incompetech.com), Licensed under Creative Commons: By Attribution 4.0",
            })
            audit_rows.append([f"km-{slugify(title)}", title, "Kevin MacLeod", "incompetech", url, "CC-BY-4.0", today, "dev CDN copy; ads-safe with attribution"])
            print(f"  ok {playlist_id}: {title} ({size // 1024} KB)")
        manifest[playlist_id] = tracks

    with open(MANIFEST, "w") as f:
        json.dump(manifest, f, indent=2, ensure_ascii=False)
    with open(SOURCES, "a", newline="") as f:
        csv.writer(f).writerows(audit_rows)

    total = sum(len(t) for t in manifest.values())
    print(f"\nverified tracks: {total} across {len(manifest)} playlists")
    for playlist_id, tracks in manifest.items():
        if len(tracks) < 3:
            print(f"  WARNING {playlist_id}: only {len(tracks)} tracks")
    if skipped:
        print("skipped (not verified — NOT shipped):")
        for playlist_id, title, why in skipped:
            print(f"  {playlist_id}: {title} — {why}")


if __name__ == "__main__":
    main()
