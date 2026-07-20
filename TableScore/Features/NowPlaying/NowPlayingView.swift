import AVKit
import SwiftUI

/// Full-screen player: large art, scrubber, transport controls, extras
/// (duck, sleep timer, AirPlay), and the up-next list.
struct NowPlayingView: View {
    @Environment(PlayerService.self) private var player
    @Environment(\.dismiss) private var dismiss

    @State private var scrubTime: Double = 0
    @State private var isScrubbing = false

    var body: some View {
        VStack(spacing: 20) {
            header
            Spacer(minLength: 0)

            ArtworkView(key: player.currentPlaylist?.id ?? player.currentTrack?.id ?? "empty")
                .frame(width: 280, height: 280)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: .black.opacity(0.6), radius: 24, y: 12)
                .accessibilityHidden(true)

            trackInfo
            scrubber
            transportControls
            extrasRow

            Spacer(minLength: 0)
            upNextSection
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .background(nowPlayingBackground.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    private var nowPlayingBackground: some View {
        ZStack {
            Theme.background
            PlaceholderArt.gradient(for: player.currentPlaylist?.id ?? player.currentTrack?.id ?? "empty")
                .opacity(0.25)
                .blur(radius: 60)
        }
    }

    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(Text("Close player"))
            Spacer()
            VStack(spacing: 2) {
                Text("Playing from")
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
                Text(player.currentPlaylist?.name ?? "")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
            }
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
    }

    private var trackInfo: some View {
        VStack(spacing: 4) {
            Text(player.currentTrack?.title ?? "")
                .font(.title2.weight(.bold))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
            Text(player.currentTrack?.artist ?? "")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var scrubber: some View {
        VStack(spacing: 4) {
            Slider(
                value: Binding(
                    get: { isScrubbing ? scrubTime : player.currentTime },
                    set: { scrubTime = $0 }
                ),
                in: 0...max(player.duration, 1)
            ) { editing in
                if editing {
                    scrubTime = player.currentTime
                    isScrubbing = true
                } else {
                    player.seek(to: scrubTime)
                    isScrubbing = false
                }
            }
            .tint(Theme.accent)
            .accessibilityLabel(Text("Playback position"))
            .accessibilityValue(Text("\(player.currentTime.trackTimeString) of \(player.duration.trackTimeString)"))

            HStack {
                Text((isScrubbing ? scrubTime : player.currentTime).trackTimeString)
                Spacer()
                Text(player.duration.trackTimeString)
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(Theme.textSecondary)
            .accessibilityHidden(true)
        }
    }

    private var transportControls: some View {
        HStack(spacing: 28) {
            Button {
                player.toggleShuffle()
            } label: {
                Image(systemName: "shuffle")
                    .font(.title3)
                    .foregroundStyle(player.isShuffled ? Theme.accent : Theme.textSecondary)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(Text(player.isShuffled ? "Shuffle on" : "Shuffle off"))

            Button {
                player.skipToPrevious()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.title)
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 52, height: 52)
            }
            .accessibilityLabel(Text("Previous track"))

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                player.togglePlayPause()
            } label: {
                Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(Theme.accent)
            }
            .accessibilityLabel(Text(player.isPlaying ? "Pause" : "Play"))

            Button {
                player.skipToNext()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.title)
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 52, height: 52)
            }
            .accessibilityLabel(Text("Next track"))

            Button {
                player.cycleRepeatMode()
            } label: {
                Image(systemName: player.repeatMode == .one ? "repeat.1" : "repeat")
                    .font(.title3)
                    .foregroundStyle(player.repeatMode == .off ? Theme.textSecondary : Theme.accent)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(repeatAccessibilityLabel)
        }
    }

    private var repeatAccessibilityLabel: Text {
        switch player.repeatMode {
        case .off: Text("Repeat off")
        case .all: Text("Repeat all")
        case .one: Text("Repeat one")
        }
    }

    private var extrasRow: some View {
        HStack(spacing: 36) {
            Button {
                player.toggleDuck()
            } label: {
                Image(systemName: player.isDucked ? "speaker.wave.1.fill" : "speaker.wave.3")
                    .font(.body)
                    .foregroundStyle(player.isDucked ? Theme.accent : Theme.textSecondary)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(Text(player.isDucked ? "Restore volume" : "Duck volume for table talk"))

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
                HStack(spacing: 4) {
                    Image(systemName: "moon.zzz")
                    if let end = player.sleepTimerEndDate {
                        Text(end, style: .timer)
                            .font(.caption.monospacedDigit())
                    }
                }
                .font(.body)
                .foregroundStyle(player.sleepTimerEndDate != nil ? Theme.accent : Theme.textSecondary)
                .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel(Text("Sleep timer"))

            AirPlayButton()
                .frame(width: 44, height: 44)
                .accessibilityLabel(Text("AirPlay"))
        }
    }

    @ViewBuilder
    private var upNextSection: some View {
        let upNext = player.upNext
        if !upNext.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Up Next")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(Array(upNext.prefix(8).enumerated()), id: \.offset) { _, track in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(track.title)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Theme.textPrimary)
                                    .lineLimit(1)
                                Text(track.artist)
                                    .font(.caption2)
                                    .foregroundStyle(Theme.textSecondary)
                                    .lineLimit(1)
                            }
                            .frame(width: 140, alignment: .leading)
                            .padding(10)
                            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 10))
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
            }
            .padding(.bottom, 8)
        }
    }
}

/// System AirPlay route picker.
private struct AirPlayButton: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.activeTintColor = UIColor(Theme.accent)
        view.tintColor = UIColor(Theme.textSecondary)
        return view
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}
