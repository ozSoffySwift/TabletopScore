import Foundation
import Observation
import SwiftUI

/// User-selected appearance: follow the system, or force light/dark.
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

/// User preferences, persisted to UserDefaults.
@MainActor
@Observable
final class AppSettings {
    private static let crossfadeKey = "settings.crossfadeDuration"
    private static let cellularKey = "settings.allowCellularStreaming"
    private static let appearanceKey = "settings.appearanceMode"
    private static let hideClassicalKey = "settings.hideClassicalMusic"

    @ObservationIgnored private let defaults: UserDefaults

    /// Seconds of overlap between tracks (0–10, spec default 4).
    var crossfadeDuration: Double {
        didSet { defaults.set(crossfadeDuration, forKey: Self.crossfadeKey) }
    }

    var allowCellularStreaming: Bool {
        didSet { defaults.set(allowCellularStreaming, forKey: Self.cellularKey) }
    }

    /// The app's canonical look is dark ("candlelight on a game table").
    var appearance: AppearanceMode {
        didSet { defaults.set(appearance.rawValue, forKey: Self.appearanceKey) }
    }

    /// Anonymous analytics opt-out; AnalyticsService reads the same key so
    /// the toggle takes effect immediately.
    var shareAnonymousUsage: Bool {
        didSet { defaults.set(shareAnonymousUsage, forKey: AnalyticsService.optInKey) }
    }

    /// Hides the Classical playlist/category from Library, Home, and Search.
    var hideClassicalMusic: Bool {
        didSet { defaults.set(hideClassicalMusic, forKey: Self.hideClassicalKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.crossfadeDuration = defaults.object(forKey: Self.crossfadeKey) as? Double ?? 4.0
        self.allowCellularStreaming = defaults.object(forKey: Self.cellularKey) as? Bool ?? true
        self.appearance = defaults.string(forKey: Self.appearanceKey)
            .flatMap(AppearanceMode.init(rawValue:)) ?? .dark
        self.shareAnonymousUsage = defaults.object(forKey: AnalyticsService.optInKey) as? Bool ?? true
        self.hideClassicalMusic = defaults.object(forKey: Self.hideClassicalKey) as? Bool ?? false
    }
}
