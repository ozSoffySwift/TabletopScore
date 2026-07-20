import Foundation

/// Anonymous usage analytics: batches events and posts them to the backend's
/// public create-only `events` collection.
///
/// Design rules (backend/README.md):
/// - Anonymous: a random per-install UUID, no user identifiers.
/// - Fire-and-forget: failures are silently dropped — analytics must NEVER
///   affect playback or surface errors.
/// - The "Share anonymous usage data" toggle is honored immediately.
final class AnalyticsService: @unchecked Sendable {
    static let shared = AnalyticsService()

    static let optInKey = "settings.shareAnonymousUsage"
    private static let deviceIDKey = "analytics.anonDeviceID"

    private let queue = DispatchQueue(label: "tablescore.analytics")
    private var pending: [[String: String]] = []
    private var flushScheduled = false

    private let anonDeviceID: String

    private init() {
        let defaults = UserDefaults.standard
        if let existing = defaults.string(forKey: Self.deviceIDKey) {
            anonDeviceID = existing
        } else {
            anonDeviceID = UUID().uuidString
            defaults.set(anonDeviceID, forKey: Self.deviceIDKey)
        }
    }

    private var isEnabled: Bool {
        UserDefaults.standard.object(forKey: Self.optInKey) as? Bool ?? true
    }

    // MARK: Event entry points

    func playStarted(trackID: String?, playlistID: String?) {
        log(type: "play_started", trackID: trackID, playlistID: playlistID)
    }

    func playlistCompleted(playlistID: String?) {
        log(type: "playlist_completed", playlistID: playlistID)
    }

    func gameOpened(gameID: String) {
        log(type: "game_opened", gameID: gameID)
    }

    // MARK: Batching

    private func log(type: String, trackID: String? = nil, gameID: String? = nil, playlistID: String? = nil) {
        guard isEnabled else { return }
        var event = [
            "type": type,
            "anonDeviceId": anonDeviceID,
            "ts": ISO8601DateFormatter().string(from: Date()),
        ]
        event["trackId"] = trackID
        event["gameId"] = gameID
        event["playlistId"] = playlistID

        queue.async {
            self.pending.append(event)
            guard !self.flushScheduled else { return }
            self.flushScheduled = true
            // Small delay batches bursts (e.g. game opened + play started).
            self.queue.asyncAfter(deadline: .now() + 5) { self.flush() }
        }
    }

    private func flush() {
        flushScheduled = false
        guard isEnabled else { pending.removeAll(); return }
        let batch = pending
        pending.removeAll()

        for event in batch {
            var request = URLRequest(url: BackendConfig.eventsURL)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: event)
            // Fire-and-forget on a background session; all outcomes ignored.
            URLSession.shared.dataTask(with: request).resume()
        }
    }
}
