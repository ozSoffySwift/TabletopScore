import Foundation
import SwiftData

/// Named `GameCategory` rather than the spec's `Category` to avoid colliding
/// with common framework type names. The raw string is stored so the group
/// can be used in #Predicate.
@Model
final class GameCategory {
    @Attribute(.unique) var id: String
    var name: String
    var groupRaw: String
    var sortIndex: Int
    @Relationship(inverse: \Playlist.categories) var playlists: [Playlist]
    @Relationship(inverse: \Game.categories) var games: [Game]

    var group: CategoryGroup { CategoryGroup(rawValue: groupRaw) ?? .genre }

    /// Catalog slug for the Classical genre category (manifest content).
    static let classicalID = "classical"

    init(id: String, name: String, group: CategoryGroup, sortIndex: Int) {
        self.id = id
        self.name = name
        self.groupRaw = group.rawValue
        self.sortIndex = sortIndex
        self.playlists = []
        self.games = []
    }
}
