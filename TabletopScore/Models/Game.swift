import Foundation
import SwiftData

/// A real board game the user browses by. Each game maps to exactly one
/// curated playlist, hand-assigned in the remote manifest — no matching
/// logic lives in the app, so curation can change server-side.
@Model
final class Game {
    @Attribute(.unique) var id: String
    var name: String
    var artworkURLString: String?
    var heroArtworkURLString: String?
    var playerCountMin: Int
    var playerCountMax: Int
    var playTimeMinutes: Int
    var popularityRank: Int
    var isFeatured: Bool
    var categories: [GameCategory]
    var playlist: Playlist?
    var lastPlayedAt: Date?
    /// Optional credit line for this game's metadata or artwork, for sources
    /// that ask to be credited. Not displayed anywhere today.
    var attributionText: String?

    var artworkURL: URL? { artworkURLString.flatMap(URL.init(string:)) }

    /// "2–4 players" / "Solo".
    var playersLabel: String {
        if playerCountMin == playerCountMax {
            return playerCountMin == 1
                ? String(localized: "Solo")
                : String(localized: "\(playerCountMin) players")
        }
        return String(localized: "\(playerCountMin)–\(playerCountMax) players")
    }

    /// "45 min" / "2 h" / "2.5 h".
    var playTimeLabel: String {
        if playTimeMinutes < 90 { return String(localized: "\(playTimeMinutes) min") }
        let hours = Double(playTimeMinutes) / 60
        let rounded = (hours * 2).rounded() / 2
        let text = rounded.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(rounded))
            : String(format: "%.1f", rounded)
        return String(localized: "\(text) h")
    }

    /// Up to two initials for the placeholder box art ("War of the Ring" → "WR").
    var initials: String {
        let stopWords: Set<String> = ["the", "of", "a", "an", "and", "for", "to"]
        let words = name
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty && !stopWords.contains($0.lowercased()) }
        let letters = words.prefix(2).compactMap { $0.first.map(String.init) }
        return letters.joined().uppercased()
    }

    /// First genre-group category, for VoiceOver ("war game").
    var primaryGenre: GameCategory? {
        categories
            .filter { $0.group == .genre }
            .sorted { $0.sortIndex < $1.sortIndex }
            .first
    }

    init(
        id: String,
        name: String,
        playerCountMin: Int = 1,
        playerCountMax: Int = 4,
        playTimeMinutes: Int = 60,
        popularityRank: Int = 0
    ) {
        self.id = id
        self.name = name
        self.artworkURLString = nil
        self.heroArtworkURLString = nil
        self.playerCountMin = playerCountMin
        self.playerCountMax = playerCountMax
        self.playTimeMinutes = playTimeMinutes
        self.popularityRank = popularityRank
        self.isFeatured = false
        self.categories = []
        self.playlist = nil
        self.lastPlayedAt = nil
        self.attributionText = nil
    }
}
