import Foundation
import SwiftData

@Model
final class Playlist {
    @Attribute(.unique) var id: String
    var name: String
    var summary: String
    var artworkURLString: String?
    var heroArtworkURLString: String?
    var isFeatured: Bool
    var sortIndex: Int
    /// SwiftData to-many relationships don't guarantee order; the manifest's
    /// track order is preserved here and resolved via `orderedTracks`.
    var orderedTrackIDs: [String]
    @Relationship(inverse: \Track.playlists) var tracks: [Track]
    var categories: [GameCategory]
    /// Games whose curated soundtrack is this playlist.
    @Relationship(inverse: \Game.playlist) var games: [Game]
    var isFavorite: Bool
    var lastPlayedAt: Date?

    var artworkURL: URL? { artworkURLString.flatMap(URL.init(string:)) }

    /// True when this playlist belongs to the "Classical" category. Drives the
    /// Library's Classical section and the "Hide classical music" setting.
    var isClassical: Bool { categories.contains { $0.id == GameCategory.classicalID } }

    var orderedTracks: [Track] {
        let byID = Dictionary(uniqueKeysWithValues: tracks.map { ($0.id, $0) })
        return orderedTrackIDs.compactMap { byID[$0] }
    }

    var totalDuration: TimeInterval {
        tracks.reduce(0) { $0 + $1.duration }
    }

    init(
        id: String,
        name: String,
        summary: String,
        artworkURLString: String? = nil,
        heroArtworkURLString: String? = nil,
        isFeatured: Bool = false,
        sortIndex: Int = 0
    ) {
        self.id = id
        self.name = name
        self.summary = summary
        self.artworkURLString = artworkURLString
        self.heroArtworkURLString = heroArtworkURLString
        self.isFeatured = isFeatured
        self.sortIndex = sortIndex
        self.orderedTrackIDs = []
        self.tracks = []
        self.categories = []
        self.games = []
        self.isFavorite = false
        self.lastPlayedAt = nil
    }
}
