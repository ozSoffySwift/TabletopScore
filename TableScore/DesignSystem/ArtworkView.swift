import SwiftUI

/// Playlist/track artwork. Loads a remote image when the catalog provides
/// one; otherwise renders the deterministic gradient placeholder. Real box
/// art is a licensing decision deferred to content curation (spec §3).
struct ArtworkView: View {
    let key: String
    var artworkURL: URL? = nil
    /// When set (game box art), the placeholder shows initials instead of a symbol.
    var initials: String? = nil

    var body: some View {
        ZStack {
            PlaceholderArt.gradient(for: key)
            if let initials {
                Text(initials)
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
                    .minimumScaleFactor(0.5)
            } else {
                Image(systemName: PlaceholderArt.symbolName(for: key))
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(.white.opacity(0.35))
            }
            if let artworkURL {
                // Real box art rarely matches our 2:3 cards exactly:
                // letterbox the sharp image over a blurred edge-fill copy
                // instead of cropping the cover. Uses the shared URLCache
                // (disk-backed, configured at app start); the gradient
                // placeholder underneath doubles as loading/failure state.
                AsyncImage(url: artworkURL) { phase in
                    if let image = phase.image {
                        ZStack {
                            image
                                .resizable()
                                .scaledToFill()
                                .blur(radius: 14, opaque: true)
                                .overlay(Color.black.opacity(0.25))
                            image
                                .resizable()
                                .scaledToFit()
                        }
                    }
                }
            }
        }
        .clipped()
        .accessibilityHidden(true) // parent cards carry the label
    }
}

/// 2:3 box-art card for a game: art with the name on one line underneath.
struct GameCard: View {
    let game: Game
    var width: CGFloat = Theme.posterWidth

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ArtworkView(key: game.id, artworkURL: game.artworkURL, initials: game.initials)
                .frame(width: width, height: width * 1.5)
                .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
            Text(game.name)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(width: width, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(game.accessibilitySummary))
        .accessibilityHint(Text("Opens game details"))
    }
}

extension Game {
    /// "Scythe, War Games, 1 to 5 players, plays Drums of War soundtrack".
    var accessibilitySummary: String {
        var parts = [name]
        if let genre = primaryGenre { parts.append(genre.name) }
        parts.append(
            playerCountMin == playerCountMax
                ? String(localized: "\(playerCountMin) players")
                : String(localized: "\(playerCountMin) to \(playerCountMax) players")
        )
        if let playlist { parts.append(String(localized: "plays \(playlist.name) soundtrack")) }
        return parts.joined(separator: ", ")
    }
}

/// 2:3 poster card used in category rows and grids.
struct PosterCard: View {
    let playlist: Playlist
    var width: CGFloat = Theme.posterWidth

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ArtworkView(key: playlist.id, artworkURL: playlist.artworkURL)
                .frame(width: width, height: width * 1.5)
                .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
                .overlay(alignment: .bottomLeading) {
                    Text(playlist.name)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            LinearGradient(
                                colors: [.clear, .black.opacity(0.75)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
                }
        }
        .frame(width: width)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(playlist.name) playlist"))
        .accessibilityHint(Text("Opens playlist details"))
    }
}
