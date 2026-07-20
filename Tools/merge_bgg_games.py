#!/usr/bin/env python3
"""Curate the BGG fetch output into TableScore's catalog schema.

Reads consept/games.json (produced by consept/fetch_game_art.py), assigns the
hand-curated soundtrack playlist per game, maps BGG categories onto our
category ids, points artwork at the DevCDN server, verifies each image file
exists, and writes Tools/curated_games.json — which Tools/gen_catalog.py
folds into the dev fixture.

Games whose BGG entry is missing a name/image, or whose id isn't in the
curation table, are DROPPED and reported rather than shipped wrong.
"""
import json
import os
import shutil

ROOT = os.path.join(os.path.dirname(__file__), "..")
SRC = os.path.join(ROOT, "consept", "games.json")
SRC_ART = os.path.join(ROOT, "consept", "art")
DEV_ART = os.path.join(ROOT, "DevCDN", "art")
OUT = os.path.join(os.path.dirname(__file__), "curated_games.json")

DEV_CDN = "http://localhost:8787/art"

# bggId -> (playlistId, extra category tags, featured)
# The playlist mapping is the product's curation (spec §2.1): exactly one
# soundtrack per game, chosen by theme.
CURATION = {
    174430: ("candlelit-crypts", ["dungeon", "fantasy", "cooperative", "heavy"], True),    # Gloomhaven
    224517: ("steam-steel", ["heavy", "euro"], True),                                      # Brass: Birmingham
    161936: ("kindled-fellowship", ["cooperative", "tense"], False),                       # Pandemic Legacy S1
    342942: ("engine-room", ["heavy", "euro"], False),                                     # Ark Nova
    233078: ("starlane-drift", ["scifi", "ameritrash", "epic-mood"], True),                # Twilight Imperium 4
    167791: ("engine-room", ["scifi", "heavy"], False),                                    # Terraforming Mars
    162886: ("kindled-fellowship", ["cooperative", "heavy", "fantasy"], False),            # Spirit Island
    291457: ("candlelit-crypts", ["dungeon", "fantasy", "cooperative"], False),            # Jaws of the Lion
    169786: ("drums-of-war", ["war", "euro", "heavy"], True),                              # Scythe
    266192: ("cozy-meadow", ["euro", "calm"], True),                                       # Wingspan
    237182: ("drums-of-war", ["war", "ameritrash", "fantasy"], False),                     # Root
    199792: ("cozy-meadow", ["fantasy", "euro", "calm"], False),                           # Everdell
    316554: ("starlane-drift", ["scifi", "deck-builders"], False),                         # Dune: Imperium
    115746: ("drums-of-war", ["war", "fantasy", "epic-mood"], False),                      # War of the Ring
    187645: ("banner-clash", ["scifi", "war", "ameritrash"], False),                       # Star Wars: Rebellion
    193738: ("meeple-meadows", ["euro", "heavy"], False),                                  # Great Western Trail
    220308: ("engine-room", ["scifi", "heavy", "euro"], False),                            # Gaia Project
    182028: ("engine-room", ["heavy", "euro"], False),                                     # Through the Ages
    124361: ("meeple-meadows", ["euro", "calm"], False),                                   # Concordia
    173346: ("duel-at-dawn", ["euro", "tense"], False),                                    # 7 Wonders Duel
    230802: ("glass-lines", ["abstract"], False),                                          # Azul
    13: ("meeple-meadows", ["euro"], False),                                               # Catan
    9209: ("iron-rails", ["trains"], False),                                               # Ticket to Ride
    822: ("meeple-meadows", ["euro"], False),                                              # Carcassonne
    36218: ("shuffle-and-spark", ["deck-builders"], False),                                # Dominion
    31260: ("meeple-meadows", ["heavy", "euro"], False),                                   # Agricola
    3076: ("meeple-meadows", ["euro"], False),                                             # Puerto Rico
    2651: ("steam-steel", ["heavy", "euro"], False),                                       # Power Grid
    84876: ("meeple-meadows", ["euro"], False),                                            # Castles of Burgundy
    164928: ("meeple-meadows", ["euro"], False),                                           # Orléans
    183394: ("cozy-meadow", ["euro", "calm"], False),                                      # Viticulture
    216132: ("meeple-meadows", ["euro", "heavy"], False),                                  # Clans of Caledonia
    185343: ("engine-room", ["scifi", "heavy"], False),                                    # Anachrony
    167355: ("eldritch-static", ["horror", "scifi", "ameritrash", "tense"], False),        # Nemesis
    170216: ("banner-clash", ["war", "ameritrash", "fantasy"], False),                     # Blood Rage
    127023: ("banner-clash", ["war", "ameritrash"], False),                                # Kemet
    253344: ("eldritch-static", ["horror", "cooperative", "ameritrash"], False),           # Cthulhu: Death May Die
    205637: ("eldritch-static", ["horror", "cooperative", "mysterious"], True),            # Arkham Horror LCG
    205059: ("eldritch-static", ["horror", "cooperative", "ameritrash"], False),           # Mansions of Madness
    146021: ("eldritch-static", ["horror", "cooperative", "ameritrash"], False),           # Eldritch Horror
    121921: ("kindled-fellowship", ["cooperative", "tense", "ameritrash"], False),         # Robinson Crusoe
    96848: ("candlelit-crypts", ["fantasy", "heavy", "dungeon"], False),                   # Mage Knight
    192135: ("candlelit-crypts", ["dungeon", "fantasy", "cooperative"], False),            # Too Many Bones
    191189: ("shuffle-and-spark", ["deck-builders", "cooperative", "fantasy"], False),     # Aeon's End
    285774: ("kindled-fellowship", ["cooperative", "fantasy"], False),                     # Marvel Champions
    77423: ("candlelit-crypts", ["fantasy", "cooperative"], False),                        # LotR: The Card Game
    12333: ("duel-at-dawn", ["war", "tense"], False),                                      # Twilight Struggle
    421: ("iron-rails", ["trains", "heavy"], False),                                       # 1830
    4098: ("iron-rails", ["trains", "heavy"], False),                                      # Age of Steam
    175914: ("steam-steel", ["heavy", "euro", "tense"], False),                            # Food Chain Magnate
    28720: ("steam-steel", ["heavy", "euro"], False),                                      # Brass: Lancashire
    35677: ("steam-steel", ["heavy", "euro"], False),                                      # Le Havre
    177736: ("meeple-meadows", ["heavy", "euro"], False),                                  # A Feast for Odin
    102794: ("meeple-meadows", ["heavy", "euro"], False),                                  # Caverna
    182874: ("meeple-meadows", ["euro"], False),                                           # Grand Austria Hotel
    203993: ("meeple-meadows", ["euro", "heavy"], False),                                  # Lorenzo il Magnifico
    126163: ("engine-room", ["euro", "heavy"], False),                                     # Tzolk'in
    102680: ("meeple-meadows", ["euro", "heavy"], False),                                  # Trajan
    171623: ("meeple-meadows", ["euro"], False),                                           # Marco Polo
    251247: ("steam-steel", ["heavy", "euro", "tense"], False),                            # Barrage
    247763: ("engine-room", ["heavy", "scifi", "euro"], False),                            # Underwater Cities
    184267: ("engine-room", ["heavy", "scifi"], False),                                    # On Mars
    161533: ("steam-steel", ["heavy", "euro"], False),                                     # Lisboa
    125153: ("engine-room", ["heavy", "euro"], False),                                     # The Gallerist
    229853: ("engine-room", ["heavy", "euro"], False),                                     # Teotihuacan
    286096: ("engine-room", ["euro"], False),                                              # Tapestry
    266524: ("cozy-meadow", ["calm", "euro"], False),                                      # PARKS
    295947: ("cozy-meadow", ["abstract", "calm"], False),                                  # Cascadia
    283155: ("cozy-meadow", ["abstract", "calm"], False),                                  # Calico
    244521: ("quick-draw", ["party-genre", "upbeat"], False),                              # Quacks of Quedlinburg
    284083: ("kindled-fellowship", ["cooperative", "scifi"], False),                       # The Crew
    254640: ("quick-draw", ["party-genre", "cooperative"], False),                         # Just One
    262543: ("banner-clash", ["party-genre", "team"], False),                              # Wavelength
    225694: ("banner-clash", ["party-genre", "team"], False),                              # Decrypto
    163412: ("glass-lines", ["abstract"], False),                                          # Patchwork
    54043: ("glass-lines", ["euro"], False),                                               # Jaipur
    50: ("glass-lines", ["euro"], False),                                                  # Lost Cities
    2655: ("glass-lines", ["abstract"], False),                                            # Hive
    194655: ("glass-lines", ["abstract"], False),                                          # Santorini
    160477: ("glass-lines", ["abstract"], False),                                          # Onitama
    147020: ("shuffle-and-spark", ["deck-builders", "scifi"], False),                      # Star Realms
    274364: ("duel-at-dawn", ["tense"], False),                                            # Watergate
    373106: ("kindled-fellowship", ["cooperative", "tense"], False),                       # Sky Team
    329082: ("duel-at-dawn", ["tense", "scifi"], False),                                   # Radlands
    68448: ("quick-draw", ["euro"], False),                                                # 7 Wonders
    30549: ("kindled-fellowship", ["cooperative", "tense"], False),                        # Pandemic
    148228: ("shuffle-and-spark", ["euro"], False),                                        # Splendor
    204583: ("cozy-meadow", ["abstract"], False),                                          # Kingdomino
    199561: ("glass-lines", ["abstract"], False),                                          # Sagrada
    262712: ("shuffle-and-spark", ["fantasy", "euro"], False),                             # Res Arcana
    271324: ("engine-room", ["euro", "scifi"], False),                                     # It's a Wonderful World
    317985: ("starlane-drift", ["scifi", "euro"], False),                                  # Beyond the Sun
    312484: ("candlelit-crypts", ["deck-builders", "fantasy", "mysterious"], False),       # Lost Ruins of Arnak
    170042: ("tavern-tales", ["euro", "upbeat"], False),                                   # Raiders of the North Sea
    236457: ("meeple-meadows", ["euro"], False),                                           # Architects of the WK
    266810: ("meeple-meadows", ["euro", "heavy"], False),                                  # Paladins of the WK
    231733: ("cozy-meadow", ["euro", "calm"], False),                                      # Obsession
    366013: ("quick-draw", ["upbeat"], False),                                             # Heat
    295770: ("candlelit-crypts", ["dungeon", "fantasy", "cooperative", "heavy"], False),   # Frosthaven
    255984: ("solo-night", ["fantasy", "cooperative", "mysterious"], False),               # Sleeping Gods
}

# BGG category names -> our category ids (supplements the hand tags).
BGG_TO_OURS = {
    "Wargame": "war", "World War II": "war",
    "Trains": "trains",
    "Fantasy": "fantasy", "Horror": "horror",
    "Science Fiction": "scifi", "Space Exploration": "scifi",
    "Party Game": "party-genre", "Abstract Strategy": "abstract",
    "Animals": "calm", "Environmental": "calm", "Farming": "calm",
    "Medieval": "euro", "Renaissance": "euro", "City Building": "euro",
    "Economic": "heavy", "Industry / Manufacturing": "heavy",
    "Deduction": "mysterious", "Murder/Mystery": "mysterious",
}


def length_tag(minutes):
    if minutes < 30: return "filler"
    if minutes <= 90: return "standard"
    if minutes <= 180: return "epic-length"
    return "marathon"


def player_tags(pmin, pmax):
    tags = []
    if pmin == 1: tags.append("solo")
    if pmax == 2: tags.append("two-player")
    if pmin <= 4 and pmax >= 3: tags.append("three-four")
    if pmax >= 5: tags.append("party-five")
    return tags


def main():
    with open(SRC) as f:
        fetched = json.load(f)["games"]

    os.makedirs(DEV_ART, exist_ok=True)
    curated, dropped = [], []
    for game in fetched:
        bgg_id = game["bggId"]
        art_file = os.path.join(SRC_ART, f"{game['id']}.jpg")
        reason = None
        if not game.get("name"):
            reason = "missing name"
        elif not game.get("artwork"):
            reason = "missing artwork"
        elif bgg_id not in CURATION:
            reason = "not in curation table"
        elif not os.path.exists(art_file):
            reason = "image file not downloaded"
        if reason:
            dropped.append((bgg_id, game.get("name"), reason))
            continue
        shutil.copy2(art_file, os.path.join(DEV_ART, f"{game['id']}.jpg"))

        playlist_id, extra_tags, featured = CURATION[bgg_id]
        pmin, pmax = game["players"]
        minutes = game["playTime"] or 60
        cats = list(extra_tags)
        for bgg_cat in game.get("bggCategories", []):
            mapped = BGG_TO_OURS.get(bgg_cat)
            if mapped and mapped not in cats:
                cats.append(mapped)
        cats.append(length_tag(minutes))
        cats.extend(t for t in player_tags(pmin, pmax) if t not in cats)
        if "cooperative" not in cats and "team" not in cats:
            cats.append("competitive")

        curated.append({
            "id": game["id"],
            "name": game["name"],
            "bggId": bgg_id,
            "artwork": f"{DEV_CDN}/{game['id']}.jpg",   # real CDN URL in production
            "heroArtwork": None,
            "players": [pmin, pmax],
            "playTime": minutes,
            "rank": game.get("rank"),
            "featured": featured,
            "categories": cats,
            "playlistId": playlist_id,
            "attribution": game.get("attribution") or "Data & images courtesy of BoardGameGeek",
        })

    curated.sort(key=lambda g: g["rank"] or 10**6)
    for index, game in enumerate(curated, start=1):
        game["rank"] = index  # densify: our popularityRank is list position

    with open(OUT, "w") as f:
        json.dump(curated, f, indent=2, ensure_ascii=False)

    playlists_used = {}
    for game in curated:
        playlists_used.setdefault(game["playlistId"], 0)
        playlists_used[game["playlistId"]] += 1
    print(f"curated={len(curated)} dropped={len(dropped)}")
    for bgg_id, name, reason in dropped:
        print(f"  DROPPED {bgg_id} {name!r}: {reason}")
    print("playlist assignment counts:")
    for playlist_id, count in sorted(playlists_used.items(), key=lambda kv: -kv[1]):
        print(f"  {playlist_id}: {count}")


if __name__ == "__main__":
    main()
