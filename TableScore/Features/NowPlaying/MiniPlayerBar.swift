import SwiftUI

/// Reserves room at the bottom of a scrollable screen for the floating
/// mini player, but only while it is showing.
struct MiniPlayerGapModifier: ViewModifier {
    @Environment(PlayerService.self) private var player

    /// Mini player bar height (artwork + padding + hairline) plus breathing room.
    static let gap: CGFloat = 76

    func body(content: Content) -> some View {
        content.safeAreaPadding(.bottom, player.currentTrack != nil ? Self.gap : 0)
    }
}

extension View {
    func miniPlayerGap() -> some View {
        modifier(MiniPlayerGapModifier())
    }
}

/// Persistent bar shown above the tab bar whenever a queue exists.
/// Tap expands the full player; long-press offers duck, sleep timer, stop.
struct MiniPlayerBar: View {
    @Environment(PlayerService.self) private var player
    @State private var showFullPlayer = false

    var body: some View {
        if let track = player.currentTrack {
            VStack(spacing: 0) {
                progressHairline
                HStack(spacing: 12) {
                    ArtworkView(key: player.currentPlaylist?.id ?? track.id)
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1)
                        Text(track.artist)
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)

                    if player.isDucked {
                        Image(systemName: "speaker.wave.1.fill")
                            .font(.caption)
                            .foregroundStyle(Theme.accent)
                            .accessibilityLabel(Text("Volume ducked"))
                    }

                    Button {
                        player.togglePlayPause()
                    } label: {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title3)
                            .foregroundStyle(Theme.textPrimary)
                            .frame(width: 40, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel(Text(player.isPlaying ? "Pause" : "Play"))

                    Button {
                        player.skipToNext()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.title3)
                            .foregroundStyle(Theme.textPrimary)
                            .frame(width: 40, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel(Text("Next track"))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .background(Theme.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
            .padding(.horizontal, 8)
            .padding(.bottom, 4)
            .contentShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
            .onTapGesture { showFullPlayer = true }
            .contextMenu { contextMenuItems }
            .fullScreenCover(isPresented: $showFullPlayer) {
                NowPlayingView()
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text("Now playing: \(track.title) by \(track.artist)"))
            .accessibilityHint(Text("Tap to open the full player"))
            .accessibilityAddTraits(.isButton)
        }
    }

    private var progressHairline: some View {
        GeometryReader { proxy in
            Rectangle()
                .fill(Theme.accent)
                .frame(
                    width: player.duration > 0
                        ? proxy.size.width * min(1, player.currentTime / player.duration)
                        : 0
                )
        }
        .frame(height: 2)
        .background(Theme.textSecondary.opacity(0.2))
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var contextMenuItems: some View {
        Button {
            player.toggleDuck()
        } label: {
            Label(
                player.isDucked ? String(localized: "Restore Volume") : String(localized: "Duck for Table Talk"),
                systemImage: player.isDucked ? "speaker.wave.3" : "speaker.wave.1"
            )
        }
        Menu {
            ForEach([15, 30, 45, 60, 90], id: \.self) { minutes in
                Button("\(minutes) min") { player.startSleepTimer(minutes: minutes) }
            }
            if player.sleepTimerEndDate != nil {
                Button(String(localized: "Cancel Timer"), role: .destructive) {
                    player.cancelSleepTimer()
                }
            }
        } label: {
            Label(String(localized: "Sleep Timer"), systemImage: "moon.zzz")
        }
        if player.isPlaying {
            Button {
                player.togglePlayPause()
            } label: {
                Label(String(localized: "Pause"), systemImage: "pause")
            }
        }
    }
}
