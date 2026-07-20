import Foundation

/// Wire format of the remote catalog.json (spec §6.1).
struct CatalogManifest: Codable, Equatable {
    var version: Int
    var updatedAt: Date
    var categories: [CategoryDTO]
    var playlists: [PlaylistDTO]
    var tracks: [TrackDTO]
    var games: [GameDTO]

    init(
        version: Int,
        updatedAt: Date,
        categories: [CategoryDTO],
        playlists: [PlaylistDTO],
        tracks: [TrackDTO],
        games: [GameDTO] = []
    ) {
        self.version = version
        self.updatedAt = updatedAt
        self.categories = categories
        self.playlists = playlists
        self.tracks = tracks
        self.games = games
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        categories = try container.decode([CategoryDTO].self, forKey: .categories)
        playlists = try container.decode([PlaylistDTO].self, forKey: .playlists)
        tracks = try container.decode([TrackDTO].self, forKey: .tracks)
        // Older manifests predate game-first browsing.
        games = try container.decodeIfPresent([GameDTO].self, forKey: .games) ?? []
    }

    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

struct CategoryDTO: Codable, Equatable {
    var id: String
    var name: String
    var group: String
    var sortIndex: Int
}

struct PlaylistDTO: Codable, Equatable {
    var id: String
    var name: String
    var summary: String
    var artwork: String?
    var heroArtwork: String?
    var categories: [String]
    var featured: Bool?
    var sortIndex: Int?
    var trackIds: [String]
}

struct GameDTO: Codable, Equatable {
    var id: String
    var name: String
    var artwork: String?
    var heroArtwork: String?
    /// [min, max]
    var players: [Int]
    var playTime: Int
    var rank: Int?
    var featured: Bool?
    var categories: [String]
    /// The hand-curated soundtrack; must reference a playlist id in this manifest.
    var playlistId: String
    /// Optional credit line for a game's metadata or artwork, carried through
    /// from the manifest for sources that ask to be credited. Unused today.
    var attribution: String?
}

struct TrackDTO: Codable, Equatable {
    var id: String
    var title: String
    var artist: String
    var duration: Double
    var url: String
    var artwork: String?
    var bytes: Int?
    // License audit trail (LICENSING.md): who wrote it, under what terms,
    // where it came from, and the exact credit line the app must display.
    var composer: String?
    var license: String?
    var sourceURL: String?
    var creditText: String?
}
