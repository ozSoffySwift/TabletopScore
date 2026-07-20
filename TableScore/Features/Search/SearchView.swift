import SwiftUI
import SwiftData

/// Search games first, then playlists — by name, description, or any
/// category tag (mood, genre, player count…).
struct SearchView: View {
    @Environment(AppSettings.self) private var settings
    @Query(sort: \Game.popularityRank) private var games: [Game]
    @Query(sort: \Playlist.name) private var playlists: [Playlist]
    @Query(sort: \GameCategory.name) private var categories: [GameCategory]
    @State private var query = ""

    /// Categories to browse/surface, honoring "Hide classical music".
    private var visibleCategories: [GameCategory] {
        settings.hideClassicalMusic
            ? categories.filter { $0.id != GameCategory.classicalID }
            : categories
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespaces)
    }

    private var matchingGames: [Game] {
        guard !trimmedQuery.isEmpty else { return [] }
        return games.filter { game in
            game.name.localizedCaseInsensitiveContains(trimmedQuery)
                || game.categories.contains { $0.name.localizedCaseInsensitiveContains(trimmedQuery) }
        }
    }

    private var matchingPlaylists: [Playlist] {
        guard !trimmedQuery.isEmpty else { return [] }
        return playlists.filter { playlist in
            (!settings.hideClassicalMusic || !playlist.isClassical)
                && (playlist.name.localizedCaseInsensitiveContains(trimmedQuery)
                    || playlist.summary.localizedCaseInsensitiveContains(trimmedQuery)
                    || playlist.categories.contains { $0.name.localizedCaseInsensitiveContains(trimmedQuery) })
        }
    }

    private var matchingCategories: [GameCategory] {
        guard !trimmedQuery.isEmpty else { return [] }
        return visibleCategories.filter {
            $0.name.localizedCaseInsensitiveContains(trimmedQuery) && !$0.playlists.isEmpty
        }
    }

    var body: some View {
        Group {
            if trimmedQuery.isEmpty {
                browseAll
            } else if matchingGames.isEmpty && matchingPlaylists.isEmpty && matchingCategories.isEmpty {
                ContentUnavailableView.search(text: trimmedQuery)
            } else {
                results
            }
        }
        .miniPlayerGap()
        .background(Theme.background)
        .navigationTitle("Search")
        .toolbarBackground(Theme.background, for: .navigationBar)
        .searchable(
            text: $query,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: Text("Playlists, moods, genres…")
        )
        .navigationDestination(for: Game.self) { GameDetailView(game: $0) }
        .navigationDestination(for: Playlist.self) { PlaylistDetailView(playlist: $0) }
        .navigationDestination(for: GameCategory.self) { CategoryGridView(category: $0) }
    }

    /// Idle state: tappable mood/genre chips to start from.
    private var browseAll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Browse by category")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                FlowingChips(categories: visibleCategories.filter { !$0.playlists.isEmpty })
            }
            .padding(16)
        }
    }

    private var results: some View {
        List {
            if !matchingGames.isEmpty {
                Section {
                    ForEach(matchingGames) { game in
                        NavigationLink(value: game) {
                            HStack(spacing: 12) {
                                ArtworkView(key: game.id, artworkURL: game.artworkURL, initials: game.initials)
                                    .frame(width: 44, height: 66)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(game.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Theme.textPrimary)
                                    Text("\(game.playersLabel) · \(game.playTimeLabel)")
                                        .font(.caption)
                                        .foregroundStyle(Theme.textSecondary)
                                    if let playlist = game.playlist {
                                        Text("Plays \(playlist.name)")
                                            .font(.caption2)
                                            .foregroundStyle(Theme.accent)
                                    }
                                }
                            }
                        }
                        .accessibilityLabel(Text(game.accessibilitySummary))
                    }
                } header: {
                    Text("Games").foregroundStyle(Theme.textSecondary)
                }
                .listRowBackground(Theme.surface)
            }
            if !matchingCategories.isEmpty {
                Section {
                    ForEach(matchingCategories) { category in
                        NavigationLink(value: category) {
                            Label(category.name, systemImage: "square.grid.2x2")
                                .foregroundStyle(Theme.textPrimary)
                        }
                    }
                } header: {
                    Text("Categories").foregroundStyle(Theme.textSecondary)
                }
                .listRowBackground(Theme.surface)
            }
            if !matchingPlaylists.isEmpty {
                Section {
                    ForEach(matchingPlaylists) { playlist in
                        NavigationLink(value: playlist) {
                            HStack(spacing: 12) {
                                ArtworkView(key: playlist.id, artworkURL: playlist.artworkURL)
                                    .frame(width: 44, height: 66)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(playlist.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Theme.textPrimary)
                                    Text(playlist.summary)
                                        .font(.caption)
                                        .foregroundStyle(Theme.textSecondary)
                                        .lineLimit(2)
                                }
                            }
                        }
                        .accessibilityLabel(Text("\(playlist.name) playlist"))
                    }
                } header: {
                    Text("Playlists").foregroundStyle(Theme.textSecondary)
                }
                .listRowBackground(Theme.surface)
            }
        }
        .scrollContentBackground(.hidden)
        .listStyle(.insetGrouped)
    }
}

/// Simple wrapping chip layout for category shortcuts.
private struct FlowingChips: View {
    let categories: [GameCategory]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 8)], spacing: 8) {
            ForEach(categories) { category in
                NavigationLink(value: category) {
                    Text(category.name)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(PlaceholderArt.gradient(for: category.id))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(.white)
                }
                .accessibilityLabel(Text("Browse \(category.name)"))
            }
        }
    }
}
