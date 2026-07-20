import AVFoundation
import MediaPlayer
import Observation
import SwiftData
import UIKit

/// The single player owned by the app (injected via .environment). Owns the
/// crossfade engine and queue, keeps the lock screen in sync, and persists
/// playback state so a session can resume after relaunch.
@MainActor
@Observable
final class PlayerService {
    // MARK: Published state

    private(set) var currentTrack: Track?
    private(set) var currentPlaylist: Playlist?
    private(set) var isPlaying = false
    private(set) var currentTime: TimeInterval = 0
    private(set) var isShuffled = false
    private(set) var repeatMode: RepeatMode = .all
    private(set) var sleepTimerEndDate: Date?
    private(set) var isDucked = false
    var playbackError: String?

    /// Stream duration once AVPlayer knows it; catalog metadata until then.
    var duration: TimeInterval {
        let live = engine.itemDuration
        if live.isFinite, live > 0 { return live }
        return currentTrack?.duration ?? 0
    }

    var upNext: [Track] { queue?.upNext ?? [] }
    var hasQueue: Bool { currentTrack != nil }

    // MARK: Internals

    @ObservationIgnored private let engine = CrossfadeEngine()
    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private var context: ModelContext?
    @ObservationIgnored private var queue: PlayQueue<Track>?
    @ObservationIgnored private var sleepTask: Task<Void, Never>?
    @ObservationIgnored private var crossfadeArmed = false
    @ObservationIgnored private var ticksSincePersist = 0
    @ObservationIgnored private var audioSessionConfigured = false

    init(settings: AppSettings) {
        self.settings = settings
        engine.onTick = { [weak self] elapsed, _ in self?.handleTick(elapsed: elapsed) }
        engine.onActiveItemEnded = { [weak self] in self?.handleTrackEnded() }
        engine.onActiveItemFailed = { [weak self] error in self?.handleStreamFailure(error) }
        registerRemoteCommands()
        observeAudioSessionNotifications()
    }

    /// Call once at launch with the main context: enables persistence and
    /// restores the previous session's queue, paused at the saved position.
    func configure(context: ModelContext) {
        self.context = context
        restorePersistedState()
    }

    // MARK: Playback entry points

    func play(playlist: Playlist, startAt index: Int = 0, shuffled: Bool = false) {
        let tracks = playlist.orderedTracks
        guard !tracks.isEmpty, streamingAllowed() else { return }

        let start = shuffled ? Int.random(in: tracks.indices) : index
        var newQueue = PlayQueue(items: tracks, startAt: start, repeatMode: repeatMode)
        if shuffled { newQueue.setShuffled(true) }
        queue = newQueue
        isShuffled = shuffled
        currentPlaylist = playlist
        playlist.lastPlayedAt = Date()
        startCurrentTrack(autoplay: true)
        persist()
    }

    func play(track: Track, in playlist: Playlist) {
        guard let index = playlist.orderedTracks.firstIndex(where: { $0.id == track.id }) else { return }
        play(playlist: playlist, startAt: index)
    }

    func togglePlayPause() {
        guard currentTrack != nil else { return }
        if isPlaying {
            engine.pause()
            isPlaying = false
            persist()
        } else {
            guard streamingAllowed() else { return }
            configureAudioSessionIfNeeded()
            engine.play()
            isPlaying = true
        }
        updateNowPlayingInfo()
    }

    func skipToNext() {
        guard var q = queue else { return }
        if let next = q.advance(userInitiated: true) {
            queue = q
            currentTrack = next
            startCurrentTrack(autoplay: isPlaying)
        } else {
            stopAtQueueEnd()
        }
    }

    func skipToPrevious() {
        guard var q = queue else { return }
        // Standard behavior: restart the track when more than 3 s in.
        if currentTime > 3 {
            seek(to: 0)
            return
        }
        _ = q.goBack()
        queue = q
        startCurrentTrack(autoplay: isPlaying)
    }

    func seek(to time: TimeInterval) {
        engine.seek(to: min(max(0, time), duration))
        currentTime = min(max(0, time), duration)
        crossfadeArmed = false
        updateNowPlayingInfo()
    }

    func toggleShuffle() {
        guard var q = queue else { return }
        q.setShuffled(!q.isShuffled)
        queue = q
        isShuffled = q.isShuffled
        persist()
    }

    func cycleRepeatMode() {
        let all = RepeatMode.allCases
        repeatMode = all[(all.firstIndex(of: repeatMode)! + 1) % all.count]
        queue?.repeatMode = repeatMode
        persist()
    }

    // MARK: Board-game extras

    func startSleepTimer(minutes: Int) {
        sleepTask?.cancel()
        let end = Date().addingTimeInterval(TimeInterval(minutes * 60))
        sleepTimerEndDate = end
        sleepTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(TimeInterval(minutes * 60) * 1_000_000_000))
            guard !Task.isCancelled, let self else { return }
            if self.isPlaying { self.togglePlayPause() }
            self.sleepTimerEndDate = nil
        }
    }

    func cancelSleepTimer() {
        sleepTask?.cancel()
        sleepTask = nil
        sleepTimerEndDate = nil
    }

    /// Halve the volume for table talk; tap again to restore.
    func toggleDuck() {
        isDucked.toggle()
        engine.volumeScale = isDucked ? 0.5 : 1.0
    }

    // MARK: Track lifecycle

    private func startCurrentTrack(autoplay: Bool) {
        guard let track = queue?.current, let url = track.streamURL else { return }
        configureAudioSessionIfNeeded()
        currentTrack = track
        currentTime = 0
        crossfadeArmed = false
        engine.load(url: url, autoplay: autoplay)
        isPlaying = autoplay
        track.playCount += 1
        currentPlaylist?.lastPlayedAt = Date()
        if autoplay {
            AnalyticsService.shared.playStarted(trackID: track.id, playlistID: currentPlaylist?.id)
        }
        updateNowPlayingInfo()
        persist()
    }

    private func handleTick(elapsed: TimeInterval) {
        currentTime = elapsed
        updateNowPlayingElapsed()

        ticksSincePersist += 1
        if ticksSincePersist >= 20 { // every ~10 s
            ticksSincePersist = 0
            persist()
        }

        // Trigger the crossfade window near the end of the track.
        let fade = settings.crossfadeDuration
        let total = duration
        guard fade > 0.1, total.isFinite, total > fade * 2, !crossfadeArmed, !engine.isCrossfading else { return }
        let remaining = total - elapsed
        guard remaining > 0.05, remaining <= fade else { return }

        guard var q = queue, let next = q.advance(userInitiated: false), let url = next.streamURL else {
            return // repeat off, last track: let it play out and end naturally
        }
        crossfadeArmed = true
        queue = q
        currentTrack = next
        next.playCount += 1
        AnalyticsService.shared.playStarted(trackID: next.id, playlistID: currentPlaylist?.id)
        engine.crossfade(to: url, duration: remaining)
        currentTime = 0
        updateNowPlayingInfo()
        persist()
    }

    /// Natural end without a crossfade (crossfade set to 0, or short track).
    private func handleTrackEnded() {
        guard var q = queue else { return }
        if let _ = q.advance(userInitiated: false) {
            queue = q
            startCurrentTrack(autoplay: true)
        } else {
            stopAtQueueEnd()
        }
    }

    /// The stream couldn't load — stop and tell the user instead of
    /// pretending to play silence.
    private func handleStreamFailure(_ error: Error?) {
        engine.pause()
        isPlaying = false
        var message = String(localized: "Couldn't play \(currentTrack?.title ?? String(localized: "this track")).")
        if let detail = error?.localizedDescription, !detail.isEmpty {
            message += " " + detail
        }
        if currentTrack?.streamURL?.host() == "localhost" {
            // Dev fixture streams from the local DevCDN server.
            message += " " + String(localized: "(Dev build: is the music server running? Run Tools/serve_devcdn.sh.)")
        }
        playbackError = message
        updateNowPlayingInfo()
    }

    private func stopAtQueueEnd() {
        engine.pause()
        engine.seek(to: 0)
        currentTime = 0
        isPlaying = false
        AnalyticsService.shared.playlistCompleted(playlistID: currentPlaylist?.id)
        updateNowPlayingInfo()
        persist()
    }

    private func streamingAllowed() -> Bool {
        let monitor = NetworkMonitor.shared
        if monitor.isExpensive && !settings.allowCellularStreaming {
            playbackError = String(localized: "Streaming over cellular is off. Enable it in Settings or connect to Wi-Fi.")
            return false
        }
        return true
    }

    // MARK: Audio session & remote commands

    private func configureAudioSessionIfNeeded() {
        guard !audioSessionConfigured else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            audioSessionConfigured = true
        } catch {
            playbackError = String(localized: "Could not start audio: \(error.localizedDescription)")
        }
    }

    private func registerRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            guard let self, !self.isPlaying else { return .commandFailed }
            self.togglePlayPause()
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            guard let self, self.isPlaying else { return .commandFailed }
            self.togglePlayPause()
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            self?.skipToNext()
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            self?.skipToPrevious()
            return .success
        }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            self?.seek(to: event.positionTime)
            return .success
        }
    }

    private func observeAudioSessionNotifications() {
        let center = NotificationCenter.default
        center.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            MainActor.assumeIsolated { self?.handleInterruption(notification) }
        }
        center.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            MainActor.assumeIsolated { self?.handleRouteChange(notification) }
        }
    }

    /// Phone call in: pause. Call ends with the resume hint: pick back up.
    private func handleInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
        switch type {
        case .began:
            if isPlaying { togglePlayPause() }
        case .ended:
            if let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt,
               AVAudioSession.InterruptionOptions(rawValue: optionsValue).contains(.shouldResume),
               !isPlaying, currentTrack != nil {
                togglePlayPause()
            }
        @unknown default:
            break
        }
    }

    /// Headphones unplugged: pause rather than blasting the table speaker.
    private func handleRouteChange(_ notification: Notification) {
        guard let info = notification.userInfo,
              let reasonValue = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue),
              reason == .oldDeviceUnavailable else { return }
        if isPlaying { togglePlayPause() }
    }

    // MARK: Now Playing info

    private func updateNowPlayingInfo() {
        guard let track = currentTrack else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        let artKey = currentPlaylist?.id ?? track.id
        let image = PlaceholderArt.image(for: artKey)
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.artist,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
            MPMediaItemPropertyArtwork: MPMediaItemArtwork(boundsSize: image.size) { _ in image },
        ]
        if let playlistName = currentPlaylist?.name {
            info[MPMediaItemPropertyAlbumTitle] = playlistName
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func updateNowPlayingElapsed() {
        guard var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPMediaItemPropertyPlaybackDuration] = duration
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    // MARK: Persistence

    private func persist() {
        guard let context else { return }
        let record = (try? context.fetch(FetchDescriptor<PlaybackStateRecord>()))?.first ?? {
            let new = PlaybackStateRecord()
            context.insert(new)
            return new
        }()
        record.currentTrackID = currentTrack?.id
        record.positionSeconds = currentTime
        record.queueTrackIDs = queue?.playOrder.compactMap { queue?.items[$0].id } ?? []
        record.playlistID = currentPlaylist?.id
        record.repeatModeRaw = repeatMode.rawValue
        record.isShuffled = isShuffled
        try? context.save()
    }

    private func restorePersistedState() {
        guard let context,
              let record = (try? context.fetch(FetchDescriptor<PlaybackStateRecord>()))?.first,
              let playlistID = record.playlistID,
              let trackID = record.currentTrackID else { return }

        let playlistDescriptor = FetchDescriptor<Playlist>(predicate: #Predicate { $0.id == playlistID })
        guard let playlist = (try? context.fetch(playlistDescriptor))?.first else { return }
        let tracks = playlist.orderedTracks
        guard let index = tracks.firstIndex(where: { $0.id == trackID }) else { return }

        repeatMode = RepeatMode(rawValue: record.repeatModeRaw) ?? .all
        var restored = PlayQueue(items: tracks, startAt: index, repeatMode: repeatMode)
        if record.isShuffled { restored.setShuffled(true) }
        queue = restored
        isShuffled = record.isShuffled
        currentPlaylist = playlist
        currentTrack = restored.current

        if let url = restored.current?.streamURL {
            engine.load(url: url, autoplay: false)
            engine.seek(to: record.positionSeconds)
            currentTime = record.positionSeconds
        }
        updateNowPlayingInfo()
    }
}
