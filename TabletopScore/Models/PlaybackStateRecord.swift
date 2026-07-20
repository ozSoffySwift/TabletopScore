import Foundation
import SwiftData

/// Singleton row: resume where you left off across launches.
@Model
final class PlaybackStateRecord {
    var currentTrackID: String?
    var positionSeconds: Double
    var queueTrackIDs: [String]
    var playlistID: String?
    var repeatModeRaw: Int
    var isShuffled: Bool

    init() {
        self.currentTrackID = nil
        self.positionSeconds = 0
        self.queueTrackIDs = []
        self.playlistID = nil
        self.repeatModeRaw = RepeatMode.all.rawValue
        self.isShuffled = false
    }
}

/// Playlists loop by default — board game sessions outlast playlists.
enum RepeatMode: Int, CaseIterable {
    case off = 0
    case all = 1
    case one = 2
}
