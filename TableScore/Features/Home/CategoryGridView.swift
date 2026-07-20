import SwiftUI

/// "See All" — vertical grid of everything in a category. Game categories
/// show box art; mood-only categories fall back to playlists.
struct CategoryGridView: View {
    let category: GameCategory

    private var games: [Game] {
        category.games.sorted { $0.popularityRank < $1.popularityRank }
    }

    private var playlists: [Playlist] {
        category.playlists.sorted { ($0.sortIndex, $0.name) < ($1.sortIndex, $1.name) }
    }

    private let columns = [
        GridItem(.adaptive(minimum: Theme.posterWidth), spacing: 12),
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                if !games.isEmpty {
                    ForEach(games) { game in
                        NavigationLink(value: game) {
                            GameCard(game: game)
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    ForEach(playlists) { playlist in
                        NavigationLink(value: playlist) {
                            PosterCard(playlist: playlist)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
        }
        .miniPlayerGap()
        .background(Theme.background)
        .navigationTitle(category.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(Theme.background, for: .navigationBar)
    }
}
