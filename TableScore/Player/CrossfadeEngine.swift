import AVFoundation

/// Two AVPlayers behind one facade so tracks can overlap during a crossfade
/// (AVQueuePlayer plays items strictly back-to-back and can't do this).
/// Streams progressively — remote URLs start playing before fully loaded.
@MainActor
final class CrossfadeEngine {
    private let players = [AVPlayer(), AVPlayer()]
    private var activeIndex = 0
    private var endObservers: [Int: NSObjectProtocol] = [:]
    private var statusObservations: [Int: NSKeyValueObservation] = [:]
    private var timeObservers: [Any] = []
    private var fadeTask: Task<Void, Never>?
    private(set) var isCrossfading = false

    /// 1.0 normally, 0.5 while ducked for table talk.
    var volumeScale: Float = 1.0 {
        didSet {
            guard !isCrossfading else { return }
            activePlayer.volume = volumeScale
        }
    }

    var onTick: ((_ elapsed: TimeInterval, _ duration: TimeInterval) -> Void)?
    var onActiveItemEnded: (() -> Void)?
    /// Fired when the active item can't load (bad URL, unreachable server…) —
    /// without this, a dead stream would just "play" silence.
    var onActiveItemFailed: ((Error?) -> Void)?

    private var activePlayer: AVPlayer { players[activeIndex] }
    private var idlePlayer: AVPlayer { players[1 - activeIndex] }

    var currentTime: TimeInterval {
        let seconds = activePlayer.currentTime().seconds
        return seconds.isFinite ? seconds : 0
    }

    /// NaN until the streaming item's duration is known.
    var itemDuration: TimeInterval {
        activePlayer.currentItem?.duration.seconds ?? .nan
    }

    var isPlaying: Bool { activePlayer.rate > 0 }

    init() {
        for (index, player) in players.enumerated() {
            player.actionAtItemEnd = .pause
            let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
            let observer = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self, index == self.activeIndex else { return }
                    self.onTick?(self.currentTime, self.itemDuration)
                }
            }
            timeObservers.append(observer)
        }
    }

    /// Hard cut: replace whatever is playing with this URL.
    func load(url: URL, autoplay: Bool) {
        cancelFade()
        idlePlayer.pause()
        idlePlayer.replaceCurrentItem(with: nil)
        let item = AVPlayerItem(url: url)
        activePlayer.replaceCurrentItem(with: item)
        activePlayer.volume = volumeScale
        observeEnd(of: item, playerIndex: activeIndex)
        if autoplay { activePlayer.play() }
    }

    /// Start the next URL on the idle player and ramp volumes over `duration`.
    func crossfade(to url: URL, duration: TimeInterval) {
        cancelFade()
        let outgoing = activePlayer
        let incoming = idlePlayer
        let item = AVPlayerItem(url: url)
        incoming.replaceCurrentItem(with: item)
        incoming.volume = 0
        incoming.play()
        activeIndex = 1 - activeIndex
        observeEnd(of: item, playerIndex: activeIndex)
        isCrossfading = true

        let scale = volumeScale
        let steps = max(1, Int(duration / 0.05))
        let stepDuration = duration / Double(steps)
        fadeTask = Task { [weak self] in
            for step in 1...steps {
                guard !Task.isCancelled else { return }
                let fraction = Float(step) / Float(steps)
                incoming.volume = fraction * scale
                outgoing.volume = (1 - fraction) * scale
                try? await Task.sleep(nanoseconds: UInt64(stepDuration * 1_000_000_000))
            }
            guard !Task.isCancelled, let self else { return }
            outgoing.pause()
            outgoing.replaceCurrentItem(with: nil)
            self.isCrossfading = false
        }
    }

    func play() {
        activePlayer.play()
    }

    func pause() {
        cancelFade()
        activePlayer.pause()
    }

    func stop() {
        cancelFade()
        for player in players {
            player.pause()
            player.replaceCurrentItem(with: nil)
        }
    }

    func seek(to time: TimeInterval) {
        cancelFade()
        let target = CMTime(seconds: max(0, time), preferredTimescale: 600)
        activePlayer.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    /// Ends any in-flight fade instantly: the incoming (active) track snaps
    /// to full volume, the outgoing one is silenced and unloaded.
    private func cancelFade() {
        fadeTask?.cancel()
        fadeTask = nil
        if isCrossfading {
            idlePlayer.pause()
            idlePlayer.replaceCurrentItem(with: nil)
            isCrossfading = false
        }
        activePlayer.volume = volumeScale
    }

    private func observeEnd(of item: AVPlayerItem, playerIndex: Int) {
        statusObservations[playerIndex] = item.observe(\.status) { [weak self] item, _ in
            guard item.status == .failed else { return }
            DispatchQueue.main.async {
                guard let self, playerIndex == self.activeIndex else { return }
                self.onActiveItemFailed?(item.error)
            }
        }
        if let old = endObservers[playerIndex] {
            NotificationCenter.default.removeObserver(old)
        }
        endObservers[playerIndex] = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification,
            object: item,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, playerIndex == self.activeIndex else { return }
                self.onActiveItemEnded?()
            }
        }
    }
}
