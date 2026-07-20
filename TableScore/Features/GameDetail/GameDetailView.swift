import SwiftUI
import SwiftData

/// One tap from game to music: large box art, game facts, and the game's
/// hand-curated soundtrack playlist inline.
struct GameDetailView: View {
    let game: Game

    @Environment(PlayerService.self) private var player
    @Environment(\.modelContext) private var context

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ArtworkView(key: game.id, artworkURL: game.artworkURL, initials: game.initials)
                    .frame(width: 200, height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
                    .shadow(color: .black.opacity(0.5), radius: 20, y: 10)

                Text(game.name)
                    .font(.title.weight(.bold))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                factChips

                if let playlist = game.playlist {
                    soundtrackSection(playlist)
                } else {
                    ContentUnavailableView(
                        "Soundtrack coming soon",
                        systemImage: "music.note",
                        description: Text("This game hasn't been matched to a playlist yet.")
                    )
                    .padding(.top, 24)
                }
            }
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .miniPlayerGap()
        .background(Theme.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .onAppear {
            AnalyticsService.shared.gameOpened(gameID: game.id)
        }
    }

    /// Player count / play time / genre & style tags.
    private var factChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(game.playersLabel, systemImage: "person.2.fill")
                chip(game.playTimeLabel, systemImage: "clock.fill")
                ForEach(sortedTagCategories) { category in
                    chip(category.name)
                }
            }
            .padding(.horizontal, 24)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(game.playersLabel), \(game.playTimeLabel), \(sortedTagCategories.map(\.name).joined(separator: ", "))"))
    }

    private var sortedTagCategories: [GameCategory] {
        game.categories
            .filter { $0.group == .genre || $0.group == .style || $0.group == .mode }
            .sorted { ($0.group.homeOrder, $0.sortIndex) < ($1.group.homeOrder, $1.sortIndex) }
    }

    private func chip(_ text: String, systemImage: String? = nil) -> some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage).font(.caption2)
            }
            Text(text).font(.caption.weight(.medium))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Theme.surface, in: Capsule())
        .foregroundStyle(Theme.textSecondary)
    }

    private func soundtrackSection(_ playlist: Playlist) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Soundtrack")
                .font(.headline)
                .foregroundStyle(Theme.textSecondary)
                .padding(.horizontal, 24)

            NavigationLink(value: playlist) {
                HStack(spacing: 12) {
                    ArtworkView(key: playlist.id, artworkURL: playlist.artworkURL)
                        .frame(width: 56, height: 84)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(playlist.name)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Theme.textPrimary)
                        Text(playlist.summary)
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(2)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.horizontal, 24)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Soundtrack: \(playlist.name)"))
            .accessibilityHint(Text("Opens playlist details"))

            HStack(spacing: 12) {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    markPlayed()
                    player.play(playlist: playlist)
                } label: {
                    Label("Play soundtrack", systemImage: "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.accent, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
                        .foregroundStyle(.black)
                }
                .accessibilityLabel(Text("Play \(game.name) soundtrack"))

                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    markPlayed()
                    player.play(playlist: playlist, shuffled: true)
                } label: {
                    Label("Shuffle", systemImage: "shuffle")
                        .font(.headline)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
                        .foregroundStyle(Theme.textPrimary)
                }
                .accessibilityLabel(Text("Shuffle \(game.name) soundtrack"))
            }
            .padding(.horizontal, 24)

            LazyVStack(spacing: 0) {
                let tracks = playlist.orderedTracks
                ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                    Button {
                        markPlayed()
                        player.play(track: track, in: playlist)
                    } label: {
                        TrackRowView(
                            index: index + 1,
                            track: track,
                            isCurrent: player.currentTrack?.id == track.id
                                && player.currentPlaylist?.id == playlist.id
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("\(track.title) by \(track.artist), \(track.duration.trackTimeString)"))
                    .accessibilityHint(Text("Plays this track"))
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func markPlayed() {
        game.lastPlayedAt = Date()
        try? context.save()
    }
}
