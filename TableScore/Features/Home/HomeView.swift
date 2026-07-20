import SwiftUI
import SwiftData

/// Game-first Home (spec §2.1): pick the game on the table, get its
/// soundtrack. Mood/playlist browsing stays as a secondary section.
struct HomeView: View {
    @Environment(AppSettings.self) private var settings

    @Query(filter: #Predicate<Game> { $0.isFeatured }, sort: \Game.popularityRank)
    private var featuredGames: [Game]

    @Query(sort: \Game.popularityRank)
    private var allGames: [Game]

    @Query(
        filter: #Predicate<Game> { $0.lastPlayedAt != nil },
        sort: \Game.lastPlayedAt,
        order: .reverse
    )
    private var recentlyPlayedGames: [Game]

    @Query private var categories: [GameCategory]

    @Query(filter: #Predicate<Playlist> { $0.isFavorite }, sort: \Playlist.name)
    private var favoritePlaylists: [Playlist]

    /// Game rows by category (genre, style, length, players, mode).
    /// Mood is reserved for the playlist section at the bottom.
    private var gameCategories: [GameCategory] {
        categories
            .filter { $0.group != .mood && !$0.games.isEmpty }
            .sorted {
                ($0.group.homeOrder, $0.sortIndex, $0.name) < ($1.group.homeOrder, $1.sortIndex, $1.name)
            }
    }

    private var moodCategories: [GameCategory] {
        categories
            .filter { $0.group == .mood && !$0.playlists.isEmpty }
            .sorted { ($0.sortIndex, $0.name) < ($1.sortIndex, $1.name) }
    }

    var body: some View {
        ScrollView {
            if allGames.isEmpty && categories.isEmpty {
                loadingSkeleton
            } else {
                LazyVStack(alignment: .leading, spacing: 28) {
                    HeroCarousel(games: featuredGames)

                    if !recentlyPlayedGames.isEmpty {
                        GameRow(
                            title: String(localized: "Recently Played Games"),
                            games: Array(recentlyPlayedGames.prefix(10))
                        )
                    }

                    GameRow(
                        title: String(localized: "Popular Games"),
                        games: Array(allGames.prefix(15))
                    )

                    ForEach(gameCategories) { category in
                        GameRow(
                            title: category.name,
                            games: category.games.sorted { $0.popularityRank < $1.popularityRank },
                            seeAllCategory: category
                        )
                    }

                    browseByMood

                    let visibleFavorites = settings.hideClassicalMusic
                        ? favoritePlaylists.filter { !$0.isClassical }
                        : favoritePlaylists
                    if !visibleFavorites.isEmpty {
                        PlaylistRow(title: String(localized: "Favorites"), playlists: visibleFavorites)
                    }
                }
                .padding(.bottom, 24)
            }
        }
        .miniPlayerGap()
        .background(Theme.background)
        .navigationTitle("Table Score")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .navigationDestination(for: Game.self) { GameDetailView(game: $0) }
        .navigationDestination(for: Playlist.self) { PlaylistDetailView(playlist: $0) }
        .navigationDestination(for: GameCategory.self) { CategoryGridView(category: $0) }
    }

    /// Secondary browse axis: moods map straight to playlists.
    @ViewBuilder
    private var browseByMood: some View {
        if !moodCategories.isEmpty {
            VStack(alignment: .leading, spacing: 20) {
                Text("Browse by Mood")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.horizontal, 16)
                ForEach(moodCategories) { category in
                    PlaylistRow(
                        title: category.name,
                        playlists: category.playlists.sorted { ($0.sortIndex, $0.name) < ($1.sortIndex, $1.name) }
                    )
                }
            }
        }
    }

    private var loadingSkeleton: some View {
        VStack(alignment: .leading, spacing: 28) {
            SkeletonBlock(height: 220)
                .padding(.horizontal, 16)
            ForEach(0..<3, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 10) {
                    SkeletonBlock(width: 140, height: 18)
                    HStack(spacing: 12) {
                        ForEach(0..<3, id: \.self) { _ in
                            SkeletonBlock(width: Theme.posterWidth, height: Theme.posterHeight)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.top, 12)
        .accessibilityLabel(Text("Loading catalog"))
    }
}

/// A horizontally scrolling row of game box-art cards.
struct GameRow: View {
    let title: String
    let games: [Game]
    var seeAllCategory: GameCategory? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let seeAllCategory {
                NavigationLink(value: seeAllCategory) {
                    HStack(spacing: 4) {
                        Text(title)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Theme.textPrimary)
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .accessibilityLabel(Text("\(title), see all"))
            } else {
                Text(title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.horizontal, 16)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) {
                    ForEach(games) { game in
                        NavigationLink(value: game) {
                            GameCard(game: game)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

/// Generic titled row of playlist posters (moods, favorites).
struct PlaylistRow: View {
    let title: String
    let playlists: [Playlist]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, 16)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) {
                    ForEach(playlists) { playlist in
                        NavigationLink(value: playlist) {
                            PosterCard(playlist: playlist)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}
