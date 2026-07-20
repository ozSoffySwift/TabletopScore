import SwiftUI

struct PlaylistDetailView: View {
    let playlist: Playlist

    @Environment(PlayerService.self) private var player
    @Environment(\.modelContext) private var context

    private var tracks: [Track] { playlist.orderedTracks }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ArtworkView(key: playlist.id, artworkURL: playlist.artworkURL)
                    .frame(width: 200, height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
                    .shadow(color: .black.opacity(0.5), radius: 20, y: 10)

                VStack(spacing: 8) {
                    Text(playlist.name)
                        .font(.title.weight(.bold))
                        .foregroundStyle(Theme.textPrimary)
                        .multilineTextAlignment(.center)
                    Text(playlist.summary)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                    Text("\(tracks.count) tracks · \(playlist.totalDuration.longDurationString)")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.horizontal, 24)

                tagStrip
                actionButtons
                trackList
            }
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .miniPlayerGap()
        .background(Theme.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    playlist.isFavorite.toggle()
                    try? context.save()
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Image(systemName: playlist.isFavorite ? "heart.fill" : "heart")
                        .foregroundStyle(playlist.isFavorite ? Theme.accent : Theme.textPrimary)
                }
                .accessibilityLabel(
                    Text(playlist.isFavorite ? "Remove from favorites" : "Add to favorites")
                )
            }
        }
    }

    private var tagStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(playlist.categories.sorted(by: { $0.name < $1.name })) { category in
                    Text(category.name)
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Theme.surface, in: Capsule())
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .padding(.horizontal, 24)
        }
        .accessibilityLabel(Text("Tags: \(playlist.categories.map(\.name).joined(separator: ", "))"))
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                player.play(playlist: playlist)
            } label: {
                Label("Play", systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.accent, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
                    .foregroundStyle(.black)
            }
            .accessibilityLabel(Text("Play \(playlist.name)"))

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                player.play(playlist: playlist, shuffled: true)
            } label: {
                Label("Shuffle", systemImage: "shuffle")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
                    .foregroundStyle(Theme.textPrimary)
            }
            .accessibilityLabel(Text("Shuffle \(playlist.name)"))
        }
        .padding(.horizontal, 24)
    }

    private var trackList: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                Button {
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

struct TrackRowView: View {
    let index: Int
    let track: Track
    let isCurrent: Bool

    var body: some View {
        HStack(spacing: 12) {
            if isCurrent {
                Image(systemName: "waveform")
                    .font(.footnote)
                    .foregroundStyle(Theme.accent)
                    .frame(width: 24)
            } else {
                Text("\(index)")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 24)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.subheadline.weight(isCurrent ? .semibold : .regular))
                    .foregroundStyle(isCurrent ? Theme.accent : Theme.textPrimary)
                    .lineLimit(1)
                Text(track.artist)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
            Text(track.duration.trackTimeString)
                .font(.caption.monospacedDigit())
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
    }
}
