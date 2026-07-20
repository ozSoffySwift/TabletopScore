#!/usr/bin/env python3
"""
fetch_game_art.py — Pull top board games' data + box art from the BoardGameGeek XML API
and emit the `games` fragment for TableScore's catalog.json.

Usage:
    pip install requests
    python3 fetch_game_art.py            # writes art/*.jpg and games.json
    python3 fetch_game_art.py --no-images  # metadata only, keep BGG image URLs

Notes:
- BGG API returns 202 while it queues a request; the script retries politely.
- Be nice to BGG: batched requests, 2s delay. Don't hammer.
- LEGAL: BGG's API terms allow non-commercial use with attribution
  ("Powered by BoardGameGeek"). For a paid/commercial app, contact BGG for a
  license. Box art copyright itself belongs to the publishers.
"""

import argparse, json, os, pathlib, sys, time
import xml.etree.ElementTree as ET

import requests

# Since 2025-07 BGG requires a registered application token for the XML API
# (https://boardgamegeek.com/using_the_xml_api). Register a NON-COMMERCIAL
# application at https://boardgamegeek.com/applications, create a token, and:
#     BGG_TOKEN=<your-token> python3 fetch_game_art.py
BGG_TOKEN = os.environ.get("BGG_TOKEN")

# ~100 popular games (BGG ids). Edit freely — names are fetched from BGG,
# so the output is always truthful even if this list changes.
GAME_IDS = [
    174430,  # Gloomhaven
    224517,  # Brass: Birmingham
    161936,  # Pandemic Legacy: Season 1
    342942,  # Ark Nova
    233078,  # Twilight Imperium: 4th Ed
    167791,  # Terraforming Mars
    162886,  # Spirit Island
    291457,  # Gloomhaven: Jaws of the Lion
    169786,  # Scythe
    266192,  # Wingspan
    237182,  # Root
    199792,  # Everdell
    316554,  # Dune: Imperium
    115746,  # War of the Ring (2nd Ed)
    187645,  # Star Wars: Rebellion
    193738,  # Great Western Trail
    220308,  # Gaia Project
    182028,  # Through the Ages: A New Story
    124361,  # Concordia
    173346,  # 7 Wonders Duel
    230802,  # Azul
    178900,  # Codenames
    13,      # Catan
    9209,    # Ticket to Ride
    822,     # Carcassonne
    36218,   # Dominion
    31260,   # Agricola
    3076,    # Puerto Rico
    2651,    # Power Grid
    84876,   # The Castles of Burgundy
    164928,  # Orléans
    183394,  # Viticulture Essential Ed
    216132,  # Clans of Caledonia
    185343,  # Anachrony
    167355,  # Nemesis
    170216,  # Blood Rage
    127023,  # Kemet
    253344,  # Cthulhu: Death May Die
    205637,  # Arkham Horror: The Card Game
    205059,  # Mansions of Madness 2nd Ed
    146021,  # Eldritch Horror
    121921,  # Robinson Crusoe
    96848,   # Mage Knight
    192135,  # Too Many Bones
    191189,  # Aeon's End
    285774,  # Marvel Champions
    77423,   # LotR: The Card Game
    12333,   # Twilight Struggle
    421,     # 1830: Railways & Robber Barons
    4098,    # Age of Steam
    175914,  # Food Chain Magnate
    28720,   # Brass: Lancashire
    35677,   # Le Havre
    177736,  # A Feast for Odin
    102794,  # Caverna
    182874,  # Grand Austria Hotel
    203993,  # Lorenzo il Magnifico
    126163,  # Tzolk'in
    102680,  # Trajan
    171623,  # The Voyages of Marco Polo
    251247,  # Barrage
    247763,  # Underwater Cities
    184267,  # On Mars
    161533,  # Lisboa
    125153,  # The Gallerist
    229853,  # Teotihuacan
    286096,  # Tapestry
    266524,  # PARKS
    295947,  # Cascadia
    283155,  # Calico
    244521,  # The Quacks of Quedlinburg
    284083,  # The Crew: Quest for Planet Nine
    254640,  # Just One
    262543,  # Wavelength
    225694,  # Decrypto
    163412,  # Patchwork
    54043,   # Jaipur
    50,      # Lost Cities
    2655,    # Hive
    194655,  # Santorini
    160477,  # Onitama
    147020,  # Star Realms
    274364,  # Watergate
    373106,  # Sky Team
    329082,  # Radlands
    68448,   # 7 Wonders
    30549,   # Pandemic
    148228,  # Splendor
    204583,  # Kingdomino
    199561,  # Sagrada
    262712,  # Res Arcana
    271324,  # It's a Wonderful World
    317985,  # Beyond the Sun
    312484,  # Lost Ruins of Arnak
    170042,  # Raiders of the North Sea
    236457,  # Architects of the West Kingdom
    266810,  # Paladins of the West Kingdom
    231733,  # Obsession
    366013,  # Heat: Pedal to the Metal
    295770,  # Frosthaven
    255984,  # Sleeping Gods
]

API = "https://boardgamegeek.com/xmlapi2/thing"
HEADERS = {"User-Agent": "TableScore-catalog-builder/1.0 (dev tooling)"}
if BGG_TOKEN:
    HEADERS["Authorization"] = f"Bearer {BGG_TOKEN}"
# Image downloads go to BGG's image CDN (different host): never send the
# API token there.
IMAGE_HEADERS = {"User-Agent": HEADERS["User-Agent"]}

# BGG category → TableScore category ids (extend as needed)
CATEGORY_MAP = {
    "Wargame": "war", "World War II": "war", "Fighting": "war",
    "Trains": "trains-18xx", "Transportation": "trains-18xx",
    "Economic": "heavy-strategy", "Industry / Manufacturing": "heavy-strategy",
    "Civilization": "epic-length", "Exploration": "adventure",
    "Adventure": "adventure", "Fantasy": "fantasy", "Horror": "horror",
    "Science Fiction": "sci-fi", "Space Exploration": "sci-fi",
    "Party Game": "party", "Card Game": "card", "Abstract Strategy": "abstract",
    "Animals": "cozy", "Environmental": "cozy", "Farming": "cozy",
    "Medieval": "euro", "Renaissance": "euro", "City Building": "euro",
    "Deduction": "mystery", "Murder/Mystery": "mystery",
}


def fetch_batch(ids):
    url = f"{API}?id={','.join(map(str, ids))}&type=boardgame&stats=1"
    for attempt in range(8):
        r = requests.get(url, headers=HEADERS, timeout=30)
        if r.status_code == 200 and r.content.strip():
            return ET.fromstring(r.content)
        # 202 = queued; anything else: back off and retry
        wait = 3 + attempt * 3
        print(f"  BGG replied {r.status_code}, retrying in {wait}s…")
        time.sleep(wait)
    sys.exit("BGG API unavailable after retries — try again later.")


def parse_item(item):
    def attr(tag, name="value"):
        el = item.find(tag)
        return el.get(name) if el is not None else None

    name = next(
        (n.get("value") for n in item.findall("name") if n.get("type") == "primary"),
        None,
    )
    cats = [
        l.get("value")
        for l in item.findall("link")
        if l.get("type") == "boardgamecategory"
    ]
    mapped = sorted({CATEGORY_MAP[c] for c in cats if c in CATEGORY_MAP})
    rank = None
    for r in item.iter("rank"):
        if r.get("name") == "boardgame" and r.get("value", "").isdigit():
            rank = int(r.get("value"))
    img = item.findtext("image")
    return {
        "id": f"bgg-{item.get('id')}",
        "bggId": int(item.get("id")),
        "name": name,
        "artwork": img,                      # replace with your CDN URL after upload
        "thumbnail": item.findtext("thumbnail"),
        "players": [
            int(attr("minplayers") or 1),
            int(attr("maxplayers") or 1),
        ],
        "playTime": int(attr("playingtime") or 0),
        "rank": rank,
        "featured": False,
        "categories": mapped or ["euro"],
        "bggCategories": cats,               # kept for curation reference
        "playlistId": "TODO-curate",         # hand-assign per game
        "attribution": "Data & images courtesy of BoardGameGeek",
    }


def main():
    if not BGG_TOKEN:
        sys.exit(
            "BGG_TOKEN is not set. The BGG XML API now requires a registered\n"
            "application token (401 otherwise). Register a non-commercial app at\n"
            "https://boardgamegeek.com/applications (approval can take a week+),\n"
            "create a token, then run:  BGG_TOKEN=<token> python3 fetch_game_art.py"
        )
    ap = argparse.ArgumentParser()
    ap.add_argument("--no-images", action="store_true", help="skip image downloads")
    ap.add_argument("--out", default="games.json")
    ap.add_argument("--art-dir", default="art")
    args = ap.parse_args()

    games = []
    for i in range(0, len(GAME_IDS), 20):
        batch = GAME_IDS[i : i + 20]
        print(f"Fetching games {i + 1}–{i + len(batch)}…")
        root = fetch_batch(batch)
        games += [parse_item(it) for it in root.findall("item")]
        time.sleep(2)

    if not args.no_images:
        art = pathlib.Path(args.art_dir)
        art.mkdir(exist_ok=True)
        for g in games:
            if not g["artwork"]:
                continue
            dest = art / f"{g['id']}.jpg"
            if dest.exists():
                continue
            print(f"  ⬇ {g['name']}")
            r = requests.get(g["artwork"], headers=IMAGE_HEADERS, timeout=60)
            r.raise_for_status()
            dest.write_bytes(r.content)
            g["localArt"] = str(dest)
            time.sleep(1)

    games.sort(key=lambda g: g["rank"] or 10**6)
    pathlib.Path(args.out).write_text(json.dumps({"games": games}, indent=2))
    print(f"\nWrote {len(games)} games to {args.out}"
          f"{'' if args.no_images else f' and box art to {args.art_dir}/'}")
    print("Next: assign playlistId per game, upload art/ to your CDN, "
          "point 'artwork' at the CDN URLs, merge into catalog.json.")


if __name__ == "__main__":
    main()
