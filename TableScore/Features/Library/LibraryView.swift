import SwiftUI
import SwiftData

/// Favorites, a Classical section, and listening history. (Downloads arrive in v1.1.)
struct LibraryView: View {
    @Environment(AppSettings.self) private var settings

    @Query(filter: #Predicate<Playlist> { $0.isFavorite }, sort: \Playlist.name)
    private var favorites: [Playlist]

    @Query(
        filter: #Predicate<Playlist> { $0.lastPlayedAt != nil },
        sort: \Playlist.lastPlayedAt,
        order: .reverse
    )
    private var recentlyPlayed: [Playlist]

    @Query(filter: #Predicate<GameCategory> { $0.id == "classical" })
    private var classicalCategories: [GameCategory]

    private let columns = [
        GridItem(.adaptive(minimum: Theme.posterWidth), spacing: 12),
    ]

    /// The "Hide classical music" setting removes classical everywhere.
    private var showClassical: Bool { !settings.hideClassicalMusic }

    private var visibleFavorites: [Playlist] {
        showClassical ? favorites : favorites.filter { !$0.isClassical }
    }

    private var visibleRecent: [Playlist] {
        showClassical ? recentlyPlayed : recentlyPlayed.filter { !$0.isClassical }
    }

    private var classicalPlaylists: [Playlist] {
        guard showClassical else { return [] }
        return classicalCategories.first?.playlists
            .sorted { ($0.sortIndex, $0.name) < ($1.sortIndex, $1.name) } ?? []
    }

    var body: some View {
        ScrollView {
            if visibleFavorites.isEmpty && visibleRecent.isEmpty && classicalPlaylists.isEmpty {
                ContentUnavailableView(
                    "Nothing here yet",
                    systemImage: "music.note.house",
                    description: Text("Heart a playlist or start playing to build your library.")
                )
                .padding(.top, 120)
            } else {
                VStack(alignment: .leading, spacing: 24) {
                    if !classicalPlaylists.isEmpty {
                        Text("Classical Music")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Theme.textPrimary)
                            .padding(.horizontal, 16)
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(classicalPlaylists) { playlist in
                                NavigationLink(value: playlist) {
                                    PosterCard(playlist: playlist)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    if !visibleFavorites.isEmpty {
                        Text("Favorites")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Theme.textPrimary)
                            .padding(.horizontal, 16)
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(visibleFavorites) { playlist in
                                NavigationLink(value: playlist) {
                                    PosterCard(playlist: playlist)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    if !visibleRecent.isEmpty {
                        Text("Recently Played")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Theme.textPrimary)
                            .padding(.horizontal, 16)
                        LazyVStack(spacing: 4) {
                            ForEach(visibleRecent) { playlist in
                                NavigationLink(value: playlist) {
                                    RecentRow(playlist: playlist)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.vertical, 16)
            }
        }
        .miniPlayerGap()
        .background(Theme.background)
        .navigationTitle("Library")
        .toolbarBackground(Theme.background, for: .navigationBar)
        .navigationDestination(for: Playlist.self) { PlaylistDetailView(playlist: $0) }
    }
}

private struct RecentRow: View {
    let playlist: Playlist

    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(key: playlist.id, artworkURL: playlist.artworkURL)
                .frame(width: 48, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text(playlist.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                if let playedAt = playlist.lastPlayedAt {
                    Text(playedAt, format: .relative(presentation: .named))
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("Opens playlist details"))
    }
}
