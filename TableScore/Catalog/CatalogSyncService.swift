import Foundation
import SwiftData

/// Upserts a catalog manifest into SwiftData. The manifest is the source of
/// truth for catalog fields; user state (favorites, play history, downloads)
/// is preserved across syncs. Objects whose ids disappear from the manifest
/// are deleted.
@MainActor
final class CatalogSyncService {
    static let lastVersionKey = "catalog.lastSyncedVersion"
    static let lastSyncDateKey = "catalog.lastSyncDate"
    static let resyncInterval: TimeInterval = 24 * 60 * 60

    private let context: ModelContext
    private let defaults: UserDefaults

    init(context: ModelContext, defaults: UserDefaults = .standard) {
        self.context = context
        self.defaults = defaults
    }

    /// Fetches the manifest (cheap: bundled file or an ETag'd request) and
    /// applies it when its version differs from the last synced one.
    /// Returns true if a sync ran.
    @discardableResult
    func syncIfNeeded(from source: CatalogSource, force: Bool = false) async throws -> Bool {
        let lastVersion = defaults.integer(forKey: Self.lastVersionKey)

        // A forced refresh must actually re-apply: drop the cached ETag so the
        // request isn't conditional (a 304 would otherwise short-circuit below,
        // leaving stale/inconsistent local data — e.g. localhost fixture URLs).
        if force {
            RemoteCatalogSource.clearCachedETag()
        }

        let manifest: CatalogManifest
        do {
            manifest = try await source.fetchManifest()
        } catch is CancellationError {
            return false // 304 Not Modified
        }

        guard force || manifest.version != lastVersion else {
            defaults.set(Date(), forKey: Self.lastSyncDateKey)
            return false
        }

        try apply(manifest)
        defaults.set(manifest.version, forKey: Self.lastVersionKey)
        defaults.set(Date(), forKey: Self.lastSyncDateKey)
        return true
    }

    /// Pure upsert + diff, separated from fetching for testability.
    func apply(_ manifest: CatalogManifest) throws {
        // --- Categories ---
        var categoriesByID = try existing(GameCategory.self, keyedBy: \.id)
        for dto in manifest.categories {
            let group = CategoryGroup(rawValue: dto.group) ?? .genre
            if let category = categoriesByID[dto.id] {
                category.name = dto.name
                category.groupRaw = group.rawValue
                category.sortIndex = dto.sortIndex
            } else {
                let category = GameCategory(id: dto.id, name: dto.name, group: group, sortIndex: dto.sortIndex)
                context.insert(category)
                categoriesByID[dto.id] = category
            }
        }

        // --- Tracks ---
        var tracksByID = try existing(Track.self, keyedBy: \.id)
        for dto in manifest.tracks {
            let track: Track
            if let existingTrack = tracksByID[dto.id] {
                track = existingTrack
                track.title = dto.title
                track.artist = dto.artist
                track.duration = dto.duration
                track.streamURLString = dto.url
                track.artworkURLString = dto.artwork
                track.fileSizeBytes = dto.bytes
            } else {
                track = Track(
                    id: dto.id,
                    title: dto.title,
                    artist: dto.artist,
                    duration: dto.duration,
                    streamURLString: dto.url,
                    artworkURLString: dto.artwork,
                    fileSizeBytes: dto.bytes
                )
                context.insert(track)
                tracksByID[dto.id] = track
            }
            track.composer = dto.composer
            track.licenseCode = dto.license
            track.sourceURLString = dto.sourceURL
            track.creditText = dto.creditText
        }

        // --- Playlists (and their relationships) ---
        var playlistsByID = try existing(Playlist.self, keyedBy: \.id)
        for (index, dto) in manifest.playlists.enumerated() {
            let playlist: Playlist
            if let existing = playlistsByID[dto.id] {
                playlist = existing
                playlist.name = dto.name
                playlist.summary = dto.summary
            } else {
                playlist = Playlist(id: dto.id, name: dto.name, summary: dto.summary)
                context.insert(playlist)
                playlistsByID[dto.id] = playlist
            }
            playlist.artworkURLString = dto.artwork
            playlist.heroArtworkURLString = dto.heroArtwork
            playlist.isFeatured = dto.featured ?? false
            playlist.sortIndex = dto.sortIndex ?? index
            playlist.orderedTrackIDs = dto.trackIds
            playlist.tracks = dto.trackIds.compactMap { tracksByID[$0] }
            playlist.categories = dto.categories.compactMap { categoriesByID[$0] }
        }

        // --- Games (curated playlist mapping lives in the manifest) ---
        var gamesByID = try existing(Game.self, keyedBy: \.id)
        for (index, dto) in manifest.games.enumerated() {
            let game: Game
            if let existingGame = gamesByID[dto.id] {
                game = existingGame
                game.name = dto.name
            } else {
                game = Game(id: dto.id, name: dto.name)
                context.insert(game)
                gamesByID[dto.id] = game
            }
            game.artworkURLString = dto.artwork
            game.heroArtworkURLString = dto.heroArtwork
            game.playerCountMin = dto.players.first ?? 1
            game.playerCountMax = dto.players.count > 1 ? dto.players[1] : (dto.players.first ?? 1)
            game.playTimeMinutes = dto.playTime
            game.popularityRank = dto.rank ?? index + 1
            game.isFeatured = dto.featured ?? false
            game.categories = dto.categories.compactMap { categoriesByID[$0] }
            game.playlist = playlistsByID[dto.playlistId]
            game.attributionText = dto.attribution
        }

        // --- Remove anything no longer in the manifest ---
        let manifestCategoryIDs = Set(manifest.categories.map(\.id))
        let manifestTrackIDs = Set(manifest.tracks.map(\.id))
        let manifestPlaylistIDs = Set(manifest.playlists.map(\.id))
        let manifestGameIDs = Set(manifest.games.map(\.id))
        for (id, game) in gamesByID where !manifestGameIDs.contains(id) {
            context.delete(game)
        }
        for (id, category) in categoriesByID where !manifestCategoryIDs.contains(id) {
            context.delete(category)
        }
        for (id, playlist) in playlistsByID where !manifestPlaylistIDs.contains(id) {
            context.delete(playlist)
        }
        for (id, track) in tracksByID where !manifestTrackIDs.contains(id) {
            context.delete(track)
        }

        try context.save()
    }

    private func existing<T: PersistentModel>(
        _ type: T.Type,
        keyedBy key: KeyPath<T, String>
    ) throws -> [String: T] {
        let all = try context.fetch(FetchDescriptor<T>())
        return Dictionary(uniqueKeysWithValues: all.map { ($0[keyPath: key], $0) })
    }
}
