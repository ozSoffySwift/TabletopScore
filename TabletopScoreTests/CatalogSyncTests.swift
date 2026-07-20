import XCTest
import SwiftData
@testable import TabletopScore

@MainActor
final class CatalogSyncTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private var sync: CatalogSyncService!

    override func setUp() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: Track.self, Playlist.self, GameCategory.self, Game.self, PlaybackStateRecord.self,
            configurations: config
        )
        context = ModelContext(container)
        sync = CatalogSyncService(context: context)
    }

    private func makeManifest(
        version: Int = 1,
        trackTitle: String = "March of Iron",
        includeSecondPlaylist: Bool = true,
        extraTrack: Bool = false,
        games: [GameDTO] = []
    ) -> CatalogManifest {
        var tracks = [
            TrackDTO(
                id: "t1", title: trackTitle, artist: "A", duration: 100,
                url: "https://example.com/1.mp3", artwork: nil, bytes: 1000,
                composer: "Kevin MacLeod", license: "CC-BY-4.0",
                sourceURL: "https://incompetech.com",
                creditText: "\"\(trackTitle)\" Kevin MacLeod (incompetech.com), CC-BY 4.0"
            ),
            TrackDTO(id: "t2", title: "Siege Lines", artist: "B", duration: 200, url: "https://example.com/2.mp3", artwork: nil, bytes: 2000, composer: nil, license: nil, sourceURL: nil, creditText: nil),
        ]
        if extraTrack {
            tracks.append(TrackDTO(id: "t3", title: "New Cut", artist: "C", duration: 300, url: "https://example.com/3.mp3", artwork: nil, bytes: 3000, composer: nil, license: nil, sourceURL: nil, creditText: nil))
        }
        var playlists = [
            PlaylistDTO(id: "p1", name: "Drums of War", summary: "War drums.", artwork: nil, heroArtwork: nil,
                        categories: ["war", "tense"], featured: true, sortIndex: 0,
                        trackIds: extraTrack ? ["t3", "t1", "t2"] : ["t1", "t2"]),
        ]
        if includeSecondPlaylist {
            playlists.append(
                PlaylistDTO(id: "p2", name: "Solo Night", summary: "Quiet.", artwork: nil, heroArtwork: nil,
                            categories: ["tense"], featured: false, sortIndex: 1, trackIds: ["t2"])
            )
        }
        return CatalogManifest(
            version: version,
            updatedAt: Date(timeIntervalSince1970: 1_752_000_000),
            categories: [
                CategoryDTO(id: "war", name: "War Games", group: "genre", sortIndex: 1),
                CategoryDTO(id: "tense", name: "Tense", group: "mood", sortIndex: 1),
            ],
            playlists: playlists,
            tracks: tracks,
            games: games
        )
    }

    private func makeGame(
        id: String = "scythe",
        name: String = "Scythe",
        playlistId: String = "p1",
        categories: [String] = ["war"],
        rank: Int = 1,
        artwork: String? = nil,
        attribution: String? = nil
    ) -> GameDTO {
        GameDTO(
            id: id, name: name, artwork: artwork, heroArtwork: nil,
            players: [1, 5], playTime: 115, rank: rank, featured: true,
            categories: categories, playlistId: playlistId, attribution: attribution
        )
    }

    func testInitialSyncInsertsEverything() throws {
        try sync.apply(makeManifest())

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Track>()), 2)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Playlist>()), 2)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<GameCategory>()), 2)

        let playlist = try fetchPlaylist("p1")
        XCTAssertEqual(playlist.orderedTracks.map(\.id), ["t1", "t2"])
        XCTAssertEqual(Set(playlist.categories.map(\.id)), ["war", "tense"])
        XCTAssertTrue(playlist.isFeatured)
    }

    func testResyncUpdatesChangedFields() throws {
        try sync.apply(makeManifest())
        try sync.apply(makeManifest(version: 2, trackTitle: "March of Steel"))

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Track>()), 2)
        let track = try XCTUnwrap(try context.fetch(FetchDescriptor<Track>()).first { $0.id == "t1" })
        XCTAssertEqual(track.title, "March of Steel")
    }

    func testResyncRemovesDeletedPlaylist() throws {
        try sync.apply(makeManifest())
        try sync.apply(makeManifest(version: 2, includeSecondPlaylist: false))

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Playlist>()), 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Playlist>()).first?.id, "p1")
        // The track that was only in the removed playlist survives; it is
        // still in the manifest's track list.
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Track>()), 2)
    }

    func testResyncAddsTrackAndPreservesManifestOrder() throws {
        try sync.apply(makeManifest())
        try sync.apply(makeManifest(version: 2, extraTrack: true))

        let playlist = try fetchPlaylist("p1")
        XCTAssertEqual(playlist.orderedTracks.map(\.id), ["t3", "t1", "t2"])
    }

    func testResyncPreservesUserState() throws {
        try sync.apply(makeManifest())
        let playlist = try fetchPlaylist("p1")
        playlist.isFavorite = true
        playlist.lastPlayedAt = Date(timeIntervalSince1970: 1_700_000_000)
        try context.save()

        try sync.apply(makeManifest(version: 2, trackTitle: "Renamed"))

        let refetched = try fetchPlaylist("p1")
        XCTAssertTrue(refetched.isFavorite)
        XCTAssertNotNil(refetched.lastPlayedAt)
    }

    func testTrackLicenseFieldsSyncOnInsertAndUpdate() throws {
        try sync.apply(makeManifest())

        let track = try XCTUnwrap(try context.fetch(FetchDescriptor<Track>()).first { $0.id == "t1" })
        XCTAssertEqual(track.composer, "Kevin MacLeod")
        XCTAssertEqual(track.licenseCode, "CC-BY-4.0")
        XCTAssertEqual(track.creditText, "\"March of Iron\" Kevin MacLeod (incompetech.com), CC-BY 4.0")

        // A resync updates the credit line (e.g. corrected attribution).
        try sync.apply(makeManifest(version: 2, trackTitle: "March of Steel"))
        let updated = try XCTUnwrap(try context.fetch(FetchDescriptor<Track>()).first { $0.id == "t1" })
        XCTAssertEqual(updated.creditText, "\"March of Steel\" Kevin MacLeod (incompetech.com), CC-BY 4.0")
    }

    // MARK: Games

    func testGameUpsertResolvesPlaylistAndCategories() throws {
        try sync.apply(makeManifest(games: [makeGame()]))

        let game = try fetchGame("scythe")
        XCTAssertEqual(game.name, "Scythe")
        XCTAssertEqual(game.playlist?.id, "p1")
        XCTAssertEqual(game.categories.map(\.id), ["war"])
        XCTAssertEqual(game.playerCountMin, 1)
        XCTAssertEqual(game.playerCountMax, 5)
        XCTAssertTrue(game.isFeatured)
    }

    func testResyncReassignsGamePlaylist() throws {
        try sync.apply(makeManifest(games: [makeGame(playlistId: "p1")]))
        // Curation moved Scythe's soundtrack server-side; no app logic involved.
        try sync.apply(makeManifest(version: 2, games: [makeGame(playlistId: "p2")]))

        let game = try fetchGame("scythe")
        XCTAssertEqual(game.playlist?.id, "p2")
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Game>()), 1)
    }

    func testResyncRemovesDeletedGame() throws {
        try sync.apply(makeManifest(games: [makeGame(), makeGame(id: "root", name: "Root", rank: 2)]))
        try sync.apply(makeManifest(version: 2, games: [makeGame()]))

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Game>()), 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Game>()).first?.id, "scythe")
    }

    func testResyncPreservesGamePlayHistory() throws {
        try sync.apply(makeManifest(games: [makeGame()]))
        let game = try fetchGame("scythe")
        game.lastPlayedAt = Date(timeIntervalSince1970: 1_700_000_000)
        try context.save()

        try sync.apply(makeManifest(version: 2, games: [makeGame(name: "Scythe (2nd Ed.)")]))

        let refetched = try fetchGame("scythe")
        XCTAssertEqual(refetched.name, "Scythe (2nd Ed.)")
        XCTAssertNotNil(refetched.lastPlayedAt)
    }

    func testGameArtworkAndAttributionUpsert() throws {
        try sync.apply(makeManifest(games: [makeGame()]))
        // Box art arrives in a later catalog version.
        try sync.apply(makeManifest(version: 2, games: [makeGame(
            artwork: "http://localhost:8787/art/scythe.jpg",
            attribution: "Artwork credit line"
        )]))

        let game = try fetchGame("scythe")
        XCTAssertEqual(game.artworkURL?.absoluteString, "http://localhost:8787/art/scythe.jpg")
        XCTAssertEqual(game.attributionText, "Artwork credit line")
    }

    func testManifestWithoutGamesArrayStillDecodes() throws {
        let json = """
        {"version": 1, "updatedAt": "2026-07-13T08:00:00Z",
         "categories": [], "playlists": [], "tracks": []}
        """
        let manifest = try CatalogManifest.decoder().decode(CatalogManifest.self, from: Data(json.utf8))
        XCTAssertTrue(manifest.games.isEmpty)
    }

    func testBundledFixtureDecodesAndMeetsSpecMinimums() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "catalog", withExtension: "json"))
        let data = try Data(contentsOf: url)
        let manifest = try CatalogManifest.decoder().decode(CatalogManifest.self, from: data)

        XCTAssertGreaterThanOrEqual(manifest.tracks.count, 60)
        XCTAssertGreaterThanOrEqual(manifest.playlists.count, 12)
        XCTAssertGreaterThanOrEqual(manifest.categories.count, 20)
        XCTAssertGreaterThanOrEqual(manifest.games.count, 100)

        // Referential integrity: every playlist's category and track ids resolve,
        // and every game's curated playlist and categories resolve.
        let categoryIDs = Set(manifest.categories.map(\.id))
        let trackIDs = Set(manifest.tracks.map(\.id))
        let playlistIDs = Set(manifest.playlists.map(\.id))
        for playlist in manifest.playlists {
            XCTAssertTrue(playlist.categories.allSatisfy(categoryIDs.contains), "dangling category in \(playlist.id)")
            XCTAssertTrue(playlist.trackIds.allSatisfy(trackIDs.contains), "dangling track in \(playlist.id)")
        }
        for game in manifest.games {
            XCTAssertTrue(playlistIDs.contains(game.playlistId), "dangling playlist in \(game.id)")
            XCTAssertTrue(game.categories.allSatisfy(categoryIDs.contains), "dangling category in \(game.id)")
            XCTAssertEqual(game.players.count, 2, "players must be [min, max] in \(game.id)")
        }

        try sync.apply(manifest)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Track>()), manifest.tracks.count)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Game>()), manifest.games.count)
    }

    private func fetchPlaylist(_ id: String) throws -> Playlist {
        let descriptor = FetchDescriptor<Playlist>(predicate: #Predicate { $0.id == id })
        return try XCTUnwrap(try context.fetch(descriptor).first)
    }

    private func fetchGame(_ id: String) throws -> Game {
        let descriptor = FetchDescriptor<Game>(predicate: #Predicate { $0.id == id })
        return try XCTUnwrap(try context.fetch(descriptor).first)
    }
}
