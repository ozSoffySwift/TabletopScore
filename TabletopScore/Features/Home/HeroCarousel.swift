import SwiftUI
import SwiftData

/// Full-width paged carousel of featured games with a gradient scrim, the
/// game name, and a "Play soundtrack" button. Auto-advances every 6 s unless
/// Reduce Motion is on.
struct HeroCarousel: View {
    let games: [Game]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selection = 0

    private let advanceInterval: TimeInterval = 6

    var body: some View {
        if games.isEmpty {
            EmptyView()
        } else {
            TabView(selection: $selection) {
                ForEach(Array(games.enumerated()), id: \.element.id) { index, game in
                    HeroCard(game: game)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .indexViewStyle(.page(backgroundDisplayMode: .never))
            .frame(height: 230)
            .task(id: reduceMotion) {
                guard !reduceMotion else { return }
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: UInt64(advanceInterval * 1_000_000_000))
                    guard !Task.isCancelled else { return }
                    withAnimation(.easeInOut) {
                        selection = (selection + 1) % max(games.count, 1)
                    }
                }
            }
        }
    }
}

private struct HeroCard: View {
    let game: Game

    @Environment(PlayerService.self) private var player
    @Environment(\.modelContext) private var context

    var body: some View {
        NavigationLink(value: game) {
            card
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Featured: \(game.accessibilitySummary)"))
        .accessibilityHint(Text("Opens game details"))
    }

    private var card: some View {
        ZStack(alignment: .bottomLeading) {
            ArtworkView(
                key: game.id,
                artworkURL: game.heroArtworkURLString.flatMap(URL.init(string:)) ?? game.artworkURL,
                initials: game.initials
            )
            LinearGradient(
                colors: [.clear, .black.opacity(0.8)],
                startPoint: .center,
                endPoint: .bottom
            )
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(game.name)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text("\(game.playersLabel) · \(game.playTimeLabel)")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.7)) // sits on the dark scrim in both themes
                }
                Spacer()
                if let playlist = game.playlist {
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        game.lastPlayedAt = Date()
                        try? context.save()
                        player.play(playlist: playlist)
                    } label: {
                        // Icon-only in a fixed circle: immune to text wrapping.
                        Image(systemName: "play.fill")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.black)
                            .frame(width: 52, height: 52)
                            .background(Theme.accent, in: Circle())
                    }
                    .accessibilityLabel(Text("Play \(game.name) soundtrack"))
                }
            }
            .padding(16)
            .padding(.bottom, 14) // keep clear of the page-indicator dots
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
        .padding(.horizontal, 16)
        .contentShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
    }
}
