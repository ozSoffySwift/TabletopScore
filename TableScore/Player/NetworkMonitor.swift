import Foundation
import Network

/// Tracks whether the current path is cellular/expensive so the
/// "stream over cellular" setting can gate playback.
final class NetworkMonitor: @unchecked Sendable {
    static let shared = NetworkMonitor()

    private let monitor = NWPathMonitor()
    private let lock = NSLock()
    private var _isExpensive = false
    private var _isConnected = true

    var isExpensive: Bool {
        lock.lock(); defer { lock.unlock() }
        return _isExpensive
    }

    var isConnected: Bool {
        lock.lock(); defer { lock.unlock() }
        return _isConnected
    }

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            self.lock.lock()
            self._isExpensive = path.isExpensive
            self._isConnected = path.status == .satisfied
            self.lock.unlock()
        }
        monitor.start(queue: DispatchQueue(label: "tablescore.network-monitor"))
    }
}
