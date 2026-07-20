import Foundation
import SwiftData

/// Catalog ids are string slugs from the remote manifest ("t001"), not UUIDs,
/// so that sync can diff by the manifest's own identifiers.
@Model
final class Track {
    @Attribute(.unique) var id: String
    var title: String
    var artist: String
    var duration: TimeInterval
    var streamURLString: String
    var artworkURLString: String?
    var fileSizeBytes: Int?
    var isDownloaded: Bool
    var localFileName: String?
    var playCount: Int
    var playlists: [Playlist]
    // License audit trail (see LICENSING.md). creditText drives the
    // Settings → Music Credits screen, which satisfies CC-BY for apps.
    var composer: String?
    var licenseCode: String?
    var sourceURLString: String?
    var creditText: String?

    var streamURL: URL? { URL(string: streamURLString) }

    init(
        id: String,
        title: String,
        artist: String,
        duration: TimeInterval,
        streamURLString: String,
        artworkURLString: String? = nil,
        fileSizeBytes: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.duration = duration
        self.streamURLString = streamURLString
        self.artworkURLString = artworkURLString
        self.fileSizeBytes = fileSizeBytes
        self.isDownloaded = false
        self.localFileName = nil
        self.playCount = 0
        self.playlists = []
        self.composer = nil
        self.licenseCode = nil
        self.sourceURLString = nil
        self.creditText = nil
    }
}
