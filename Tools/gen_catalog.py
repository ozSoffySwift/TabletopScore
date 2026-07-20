#!/usr/bin/env python3
"""Generate the development fixture catalog.json for TableScore.

Run from the repo root:  python3 Tools/gen_catalog.py

Tracks come from Tools/music_manifest.json — real Kevin MacLeod (CC-BY 4.0,
ads-safe) MP3s downloaded and verified by Tools/fetch_music.py, served from
the local DevCDN (Tools/serve_devcdn.sh). Playlists map to board-game
contexts per spec §2; games are the primary browse axis (spec §2.1) and each
maps to exactly one hand-curated playlist. Bump VERSION whenever the content
changes, or synced installs will skip the update.
"""
import json, os

VERSION = 5

MUSIC_MANIFEST = os.path.join(os.path.dirname(__file__), "music_manifest.json")

# When Tools/merge_bgg_games.py has produced curated_games.json (real BGG
# metadata + box art via the DevCDN server), it replaces the hand-written
# GAMES table below as the games source. Bump VERSION when that happens.
CURATED_GAMES = os.path.join(os.path.dirname(__file__), "curated_games.json")

categories = []
def cat(id, name, group, idx):
    categories.append({"id": id, "name": name, "group": group, "sortIndex": idx})

# genre (8)
cat("war", "War Games", "genre", 1)
cat("trains", "18xx & Trains", "genre", 2)
cat("euro", "Eurogames", "genre", 3)
cat("dungeon", "Dungeon Crawlers", "genre", 4)
cat("horror", "Horror", "genre", 5)
cat("scifi", "Sci-Fi", "genre", 6)
cat("fantasy", "Fantasy", "genre", 7)
cat("party-genre", "Party Games", "genre", 8)
# style (5)
cat("heavy", "Heavy Strategy", "style", 1)
cat("ameritrash", "Ameritrash", "style", 2)
cat("abstract", "Abstract", "style", 3)
cat("deck-builders", "Deck Builders", "style", 4)
cat("roll-write", "Roll & Write", "style", 5)
# length (4)
cat("filler", "Filler (<30 min)", "length", 1)
cat("standard", "Standard (30–90 min)", "length", 2)
cat("epic-length", "Epic (90 min–3 h)", "length", 3)
cat("marathon", "Marathon (3 h+)", "length", 4)
# playerCount (4)
cat("solo", "Solo", "playerCount", 1)
cat("two-player", "Two-Player Duels", "playerCount", 2)
cat("three-four", "3–4 Players", "playerCount", 3)
cat("party-five", "Party (5+)", "playerCount", 4)
# mode (3)
cat("competitive", "Competitive", "mode", 1)
cat("cooperative", "Cooperative", "mode", 2)
cat("team", "Team vs. Team", "mode", 3)
# mood (5)
cat("tense", "Tense", "mood", 1)
cat("calm", "Calm", "mood", 2)
cat("epic-mood", "Epic", "mood", 3)
cat("mysterious", "Mysterious", "mood", 4)
cat("upbeat", "Upbeat", "mood", 5)

# (playlist id, name, summary, featured, categories, legacy fixture titles —
#  unused since tracks moved to music_manifest.json)
PLAYLISTS = [
    ("drums-of-war", "Drums of War",
     "Martial percussion and low brass for long campaigns across hex and counter.",
     True, ["war", "epic-length", "competitive", "tense", "heavy", "ameritrash", "three-four"],
     ["March of Iron", "Siege Lines", "Powder and Smoke", "The Long Retreat", "Banners at Dawn"]),
    ("iron-rails", "Iron Rails",
     "Steady, driving themes for stock rounds and track-laying marathons.",
     True, ["trains", "marathon", "heavy", "competitive", "calm", "euro", "three-four"],
     ["Gauge and Grade", "Dividend Run", "Coal Country", "The Timetable", "Terminus"]),
    ("meeple-meadows", "Meeple Meadows",
     "Warm pastoral strings and woodwinds for worker placement evenings.",
     False, ["euro", "standard", "three-four", "calm", "competitive", "heavy"],
     ["Harvest Rondo", "The Granary", "Field and Fence", "Market Day", "Twilight Sowing"]),
    ("candlelit-crypts", "Candlelit Crypts",
     "Torchlit corridors, distant drums, and the clink of looted gold.",
     False, ["dungeon", "fantasy", "epic-length", "mysterious", "cooperative", "ameritrash", "three-four", "epic-mood"],
     ["Into the Under", "Trapfinder", "Bones of the Keep", "The Sealed Door", "Dragon's Ledger"]),
    ("eldritch-static", "Eldritch Static",
     "Unsettling drones and whispered choirs for cooperative horror nights.",
     True, ["horror", "tense", "cooperative", "mysterious", "ameritrash", "epic-length", "solo"],
     ["The Rift Opens", "Half-Seen Things", "Sanity Check", "Vestibule", "It Was Already Here"]),
    ("starlane-drift", "Starlane Drift",
     "Weightless synth pads for engine building among the stars.",
     False, ["scifi", "calm", "solo", "standard", "heavy", "mysterious", "two-player"],
     ["Ion Wake", "Cryo Morning", "Orbital Garden", "Signal from Kepler", "Slow Burn to Mars"]),
    ("tavern-tales", "Tavern Tales",
     "Lutes, fiddles, and clinking mugs for lighthearted fantasy romps.",
     False, ["fantasy", "party-genre", "upbeat", "party-five", "ameritrash", "filler", "team"],
     ["The Prancing Griffin", "Ale and Aces", "Bard's Wager", "Copper for a Story", "Last Call at the Keep"]),
    ("quick-draw", "Quick Draw",
     "Snappy, bright loops for fillers and roll-and-writes between rounds.",
     False, ["filler", "party-five", "upbeat", "roll-write", "party-genre", "competitive", "two-player"],
     ["Dice on the Table", "Scribble Sprint", "Bonus Round", "Fast Money", "One More Game"]),
    ("duel-at-dawn", "Duel at Dawn",
     "Coiled-spring tension for head-to-head duels and gambits.",
     False, ["two-player", "competitive", "tense", "standard", "abstract", "war"],
     ["First Move", "Zugzwang", "The Feint", "Tempo Steal", "Checkmate Weather"]),
    ("solo-night", "Solo Night",
     "Intimate piano and soft static for late-night solitaire campaigns.",
     True, ["solo", "calm", "mysterious", "standard", "roll-write", "euro"],
     ["Table for One", "Automa Waltz", "The Quiet Deck", "Midnight Upkeep", "Final Score, Whispered"]),
    ("kindled-fellowship", "Kindled Fellowship",
     "Hopeful, swelling themes for co-ops where everyone wins or no one does.",
     False, ["cooperative", "three-four", "epic-mood", "epic-length", "fantasy", "dungeon", "team"],
     ["Shoulder to Shoulder", "The Shared Map", "Last Action Hero", "Against the Deck", "We Hold the Line"]),
    ("shuffle-and-spark", "Shuffle & Spark",
     "Crisp electro-swing energy for deck builders and combo turns.",
     False, ["deck-builders", "standard", "upbeat", "competitive", "three-four", "two-player", "filler"],
     ["Opening Hand", "Trash for Treasure", "The Engine Hums", "Combo Piece", "Victory Pile"]),
    ("glass-lines", "Glass Lines",
     "Minimal, crystalline patterns for abstracts and perfect information.",
     False, ["abstract", "two-player", "calm", "filler", "euro", "solo"],
     ["Lattice", "Symmetry Break", "Cold Elegance", "The Grid Breathes", "Endgame Geometry"]),
    ("banner-clash", "Banner Clash",
     "Anthemic team-versus-team energy for shouting across the table.",
     False, ["team", "party-five", "epic-mood", "party-genre", "competitive", "upbeat", "war"],
     ["Choose Your Side", "The Standard Bearer", "Rally Point", "Overtime Legends", "Glory Round"]),
    ("steam-steel", "Steam & Steel",
     "Pistons, furnaces, and dividend bells for industrial empires.",
     False, ["heavy", "trains", "standard", "competitive", "tense", "euro"],
     ["Blast Furnace", "Canal Era", "The Rail Baron", "Coal and Clay", "Closing Bell"]),
    ("engine-room", "Engine Room",
     "Clockwork rhythms for engine builders and point-salad perfectionists.",
     False, ["euro", "heavy", "standard", "competitive", "upbeat", "solo"],
     ["Prototype", "Compound Interest", "The Optimizer", "Assembly Line Waltz", "Exponential"]),
    ("cozy-meadow", "Cozy Meadow",
     "Gentle folk melodies for families, birds, and quiet valleys.",
     False, ["euro", "calm", "filler", "three-four", "upbeat", "standard"],
     ["Dandelion Drift", "Birdsong Morning", "The Old Oak", "Creekside", "Lantern Evening"]),
]

# Tracks: verified CC-BY downloads from Tools/fetch_music.py, one bundle per
# playlist. Each entry already carries the full license audit fields
# (composer / license / sourceURL / creditText — see LICENSING.md).
with open(MUSIC_MANIFEST) as f:
    music = json.load(f)

tracks, playlists = [], []
seen_track_ids = set()
for p_idx, (pid, name, summary, featured, cats, _legacy_titles) in enumerate(PLAYLISTS):
    playlist_tracks = music.get(pid, [])
    assert playlist_tracks, f"no verified tracks for playlist {pid} — rerun Tools/fetch_music.py"
    for track in playlist_tracks:
        if track["id"] not in seen_track_ids:
            seen_track_ids.add(track["id"])
            tracks.append(track)
    playlists.append({
        "id": pid, "name": name, "summary": summary,
        "categories": cats, "featured": featured,
        "sortIndex": p_idx, "trackIds": [t["id"] for t in playlist_tracks],
    })

# ---------------------------------------------------------------------------
# Games: ~100 popular modern titles (BGG-flavored). Each maps to exactly ONE
# curated playlist — the mapping is content, not code (spec §2.1). Rank is
# the list position. Length & player-count categories are derived; genre,
# style, and mode tags are hand-assigned.
#
# (name, min, max, minutes, [manual tags], playlistId, featured)
GAMES = [
    ("Gloomhaven", 1, 4, 120, ["dungeon", "fantasy", "cooperative", "heavy"], "candlelit-crypts", True),
    ("Brass: Birmingham", 2, 4, 120, ["heavy", "euro"], "steam-steel", True),
    ("Pandemic Legacy: Season 1", 2, 4, 60, ["cooperative", "tense"], "kindled-fellowship", False),
    ("Ark Nova", 1, 4, 150, ["heavy", "euro"], "engine-room", False),
    ("Twilight Imperium: Fourth Edition", 3, 6, 480, ["scifi", "ameritrash", "epic-mood"], "starlane-drift", True),
    ("Spirit Island", 1, 4, 120, ["cooperative", "heavy", "fantasy"], "kindled-fellowship", False),
    ("Scythe", 1, 5, 115, ["war", "euro", "heavy"], "drums-of-war", True),
    ("Wingspan", 1, 5, 70, ["euro", "calm"], "cozy-meadow", True),
    ("Terraforming Mars", 1, 5, 120, ["scifi", "heavy", "euro"], "engine-room", False),
    ("Root", 2, 4, 90, ["war", "ameritrash", "fantasy"], "drums-of-war", False),
    ("Everdell", 1, 4, 80, ["fantasy", "euro", "calm"], "cozy-meadow", False),
    ("Dune: Imperium", 1, 4, 120, ["scifi", "deck-builders"], "starlane-drift", False),
    ("Gaia Project", 1, 4, 150, ["scifi", "heavy", "euro"], "engine-room", False),
    ("War of the Ring: Second Edition", 2, 4, 180, ["war", "fantasy", "ameritrash", "epic-mood"], "drums-of-war", False),
    ("Star Wars: Rebellion", 2, 4, 240, ["scifi", "war", "ameritrash"], "banner-clash", False),
    ("Great Western Trail", 1, 4, 150, ["euro", "heavy"], "meeple-meadows", False),
    ("The Castles of Burgundy", 1, 4, 90, ["euro"], "meeple-meadows", False),
    ("Concordia", 2, 5, 100, ["euro", "calm"], "meeple-meadows", False),
    ("7 Wonders Duel", 2, 2, 30, ["euro", "competitive"], "duel-at-dawn", False),
    ("Codenames", 2, 8, 15, ["party-genre", "team"], "quick-draw", False),
    ("Azul", 2, 4, 45, ["abstract"], "glass-lines", False),
    ("Catan", 3, 4, 90, ["euro"], "meeple-meadows", False),
    ("Ticket to Ride", 2, 5, 60, ["trains"], "iron-rails", False),
    ("Carcassonne", 2, 5, 45, ["euro"], "meeple-meadows", False),
    ("Pandemic", 2, 4, 45, ["cooperative", "tense"], "kindled-fellowship", False),
    ("Dominion", 2, 4, 30, ["deck-builders"], "shuffle-and-spark", False),
    ("Splendor", 2, 4, 30, ["euro"], "shuffle-and-spark", False),
    ("Patchwork", 2, 2, 30, ["abstract"], "glass-lines", False),
    ("Terra Mystica", 2, 5, 150, ["heavy", "fantasy", "euro"], "engine-room", False),
    ("Blood Rage", 2, 4, 90, ["war", "ameritrash", "fantasy"], "banner-clash", False),
    ("A Feast for Odin", 1, 4, 120, ["heavy", "euro"], "meeple-meadows", False),
    ("Orléans", 2, 4, 90, ["euro"], "meeple-meadows", False),
    ("Viticulture Essential Edition", 1, 6, 90, ["euro", "calm"], "cozy-meadow", False),
    ("The Crew: The Quest for Planet Nine", 2, 5, 20, ["cooperative", "scifi"], "kindled-fellowship", False),
    ("Lost Ruins of Arnak", 1, 4, 90, ["deck-builders", "fantasy", "mysterious"], "candlelit-crypts", False),
    ("Barrage", 1, 4, 120, ["heavy", "euro", "tense"], "steam-steel", False),
    ("Underwater Cities", 1, 4, 120, ["heavy", "scifi", "euro"], "engine-room", False),
    ("Le Havre", 1, 5, 150, ["heavy", "euro"], "steam-steel", False),
    ("Agricola", 1, 4, 120, ["heavy", "euro"], "meeple-meadows", False),
    ("Puerto Rico", 3, 5, 90, ["euro"], "meeple-meadows", False),
    ("Power Grid", 2, 6, 120, ["heavy", "euro"], "steam-steel", False),
    ("1830: Railways & Robber Barons", 2, 7, 240, ["trains", "heavy"], "iron-rails", False),
    ("1846: The Race for the Midwest", 3, 5, 240, ["trains", "heavy"], "iron-rails", False),
    ("18Chesapeake", 2, 6, 180, ["trains", "heavy"], "iron-rails", False),
    ("Food Chain Magnate", 2, 5, 180, ["heavy", "euro", "tense"], "steam-steel", False),
    ("Through the Ages: A New Story of Civilization", 2, 4, 240, ["heavy", "euro"], "engine-room", False),
    ("Twilight Struggle", 2, 2, 180, ["war", "tense"], "duel-at-dawn", False),
    ("Star Realms", 2, 2, 25, ["deck-builders", "scifi"], "shuffle-and-spark", False),
    ("Marvel Champions: The Card Game", 1, 4, 90, ["cooperative", "fantasy"], "kindled-fellowship", False),
    ("Arkham Horror: The Card Game", 1, 4, 120, ["horror", "cooperative", "mysterious"], "eldritch-static", True),
    ("Eldritch Horror", 1, 8, 240, ["horror", "cooperative", "ameritrash"], "eldritch-static", False),
    ("Mansions of Madness: Second Edition", 1, 5, 150, ["horror", "cooperative", "ameritrash"], "eldritch-static", False),
    ("Betrayal at House on the Hill", 3, 6, 60, ["horror", "ameritrash", "party-genre"], "eldritch-static", False),
    ("Dead of Winter", 2, 5, 120, ["horror", "cooperative", "tense"], "eldritch-static", False),
    ("Nemesis", 1, 5, 150, ["horror", "scifi", "ameritrash", "tense"], "eldritch-static", False),
    ("Mage Knight", 1, 4, 150, ["fantasy", "heavy", "dungeon"], "candlelit-crypts", False),
    ("Gloomhaven: Jaws of the Lion", 1, 4, 90, ["dungeon", "fantasy", "cooperative"], "candlelit-crypts", False),
    ("Descent: Legends of the Dark", 1, 4, 150, ["dungeon", "fantasy", "cooperative"], "candlelit-crypts", False),
    ("Too Many Bones", 1, 4, 120, ["dungeon", "fantasy", "cooperative"], "candlelit-crypts", False),
    ("Sleeping Gods", 1, 4, 120, ["fantasy", "cooperative", "mysterious"], "solo-night", False),
    ("Robinson Crusoe: Adventures on the Cursed Island", 1, 4, 120, ["cooperative", "tense", "ameritrash"], "kindled-fellowship", False),
    ("The 7th Continent", 1, 4, 120, ["mysterious", "cooperative"], "solo-night", False),
    ("Friday", 1, 1, 25, ["deck-builders"], "solo-night", False),
    ("Onirim", 1, 2, 15, ["mysterious"], "solo-night", False),
    ("Spirit Island: Jagged Earth", 1, 6, 120, ["cooperative", "heavy", "fantasy"], "kindled-fellowship", False),
    ("Cascadia", 1, 4, 45, ["abstract", "calm"], "cozy-meadow", False),
    ("Calico", 1, 4, 45, ["abstract", "calm"], "cozy-meadow", False),
    ("PARKS", 1, 5, 60, ["calm", "euro"], "cozy-meadow", False),
    ("Meadow", 1, 4, 90, ["calm", "euro"], "cozy-meadow", False),
    ("Photosynthesis", 2, 4, 60, ["abstract", "calm"], "cozy-meadow", False),
    ("Santorini", 2, 2, 20, ["abstract"], "glass-lines", False),
    ("Hive", 2, 2, 20, ["abstract"], "glass-lines", False),
    ("Onitama", 2, 2, 15, ["abstract"], "glass-lines", False),
    ("Tak", 2, 2, 30, ["abstract"], "glass-lines", False),
    ("The Quacks of Quedlinburg", 2, 4, 45, ["party-genre", "upbeat"], "quick-draw", False),
    ("Camel Up", 3, 8, 30, ["party-genre", "upbeat"], "quick-draw", False),
    ("Just One", 3, 7, 20, ["party-genre", "cooperative"], "quick-draw", False),
    ("Wavelength", 2, 12, 45, ["party-genre", "team"], "banner-clash", False),
    ("Decrypto", 3, 8, 45, ["party-genre", "team"], "banner-clash", False),
    ("Captain Sonar", 2, 8, 45, ["team", "tense", "party-genre"], "banner-clash", False),
    ("Skull King", 2, 8, 30, ["party-genre", "upbeat"], "tavern-tales", False),
    ("The Red Dragon Inn", 2, 4, 60, ["fantasy", "party-genre", "upbeat"], "tavern-tales", False),
    ("Sheriff of Nottingham", 3, 5, 60, ["party-genre", "upbeat"], "tavern-tales", False),
    ("Libertalia: Winds of Galecrest", 1, 6, 60, ["ameritrash", "upbeat"], "tavern-tales", False),
    ("Dixit", 3, 8, 30, ["party-genre", "mysterious"], "tavern-tales", False),
    ("Mysterium", 2, 7, 45, ["cooperative", "mysterious", "party-genre"], "eldritch-static", False),
    ("Ganz Schön Clever", 1, 4, 30, ["roll-write"], "quick-draw", False),
    ("Welcome To...", 1, 100, 25, ["roll-write"], "quick-draw", False),
    ("Railroad Ink: Deep Blue Edition", 1, 6, 30, ["roll-write", "trains"], "quick-draw", False),
    ("Cartographers", 1, 100, 45, ["roll-write", "fantasy"], "quick-draw", False),
    ("Clank!: A Deck-Building Adventure", 2, 4, 60, ["deck-builders", "dungeon", "fantasy"], "shuffle-and-spark", False),
    ("Aeon's End", 1, 4, 60, ["deck-builders", "cooperative", "fantasy"], "shuffle-and-spark", False),
    ("Undaunted: Normandy", 2, 2, 60, ["war", "deck-builders"], "duel-at-dawn", False),
    ("Memoir '44", 2, 2, 60, ["war", "ameritrash"], "duel-at-dawn", False),
    ("Summoner Wars: Second Edition", 2, 2, 40, ["fantasy", "tense"], "duel-at-dawn", False),
    ("Radlands", 2, 2, 45, ["tense", "scifi"], "duel-at-dawn", False),
    ("Sky Team", 2, 2, 20, ["cooperative", "tense"], "kindled-fellowship", False),
    ("Heat: Pedal to the Metal", 1, 6, 60, ["upbeat"], "quick-draw", False),
    ("Res Arcana", 2, 4, 45, ["fantasy", "euro"], "shuffle-and-spark", False),
    ("Obsession", 1, 4, 90, ["euro", "calm"], "cozy-meadow", False),
    ("Lords of Waterdeep", 2, 5, 90, ["euro", "fantasy"], "meeple-meadows", False),
    ("7 Wonders", 3, 7, 30, ["euro"], "quick-draw", False),
    ("Kingdomino", 2, 4, 15, ["abstract"], "cozy-meadow", False),
    ("Jaipur", 2, 2, 30, ["euro"], "glass-lines", False),
    ("Lost Cities", 2, 2, 30, ["euro"], "glass-lines", False),
]

def slugify(name):
    out = []
    for ch in name.lower():
        if ch.isalnum():
            out.append(ch)
        elif out and out[-1] != "-":
            out.append("-")
    return "".join(out).strip("-")

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

playlist_ids = {p["id"] for p in playlists}
category_ids = {c["id"] for c in categories}

if os.path.exists(CURATED_GAMES):
    with open(CURATED_GAMES) as f:
        games = json.load(f)
    for g in games:
        assert g["playlistId"] in playlist_ids, f"{g['name']}: unknown playlist {g['playlistId']}"
        assert all(c in category_ids for c in g["categories"]), f"{g['name']}: bad category"
    print(f"using curated BGG games from {os.path.basename(CURATED_GAMES)}")
else:
    games = []
    seen_ids = set()
    for rank, (name, pmin, pmax, minutes, tags, playlist_id, featured) in enumerate(GAMES, start=1):
        gid = slugify(name)
        assert gid not in seen_ids, f"duplicate game id {gid}"
        seen_ids.add(gid)
        assert playlist_id in playlist_ids, f"{name}: unknown playlist {playlist_id}"
        cats = list(dict.fromkeys(tags + [length_tag(minutes)] + player_tags(pmin, pmax)))
        if "cooperative" not in cats and "team" not in cats:
            cats.append("competitive")
        assert all(c in category_ids for c in cats), f"{name}: bad category in {cats}"
        games.append({
            "id": gid,
            "name": name,
            "artwork": None,       # licensed box art URL goes here (see README)
            "heroArtwork": None,   # 16:9 hero variant for featured games
            "players": [pmin, pmax],
            "playTime": minutes,
            "rank": rank,
            "featured": featured,
            "categories": cats,
            "playlistId": playlist_id,
        })

manifest = {
    "version": VERSION,
    "updatedAt": "2026-07-13T08:00:00Z",
    "categories": categories,
    "playlists": playlists,
    "tracks": tracks,
    "games": games,
}
out = os.path.join(os.path.dirname(__file__), "..", "TableScore", "Resources", "catalog.json")
with open(out, "w") as f:
    json.dump(manifest, f, indent=2, ensure_ascii=False)
print(f"tracks={len(tracks)} playlists={len(playlists)} categories={len(categories)} games={len(games)}")
