import SwiftUI
import SwiftData

@main
struct TabletopScoreApp: App {
    private let container: ModelContainer
    @State private var settings: AppSettings
    @State private var player: PlayerService
    @State private var showSplash = true

    init() {
        // Box art is remote-only; give AsyncImage's shared cache real disk room.
        URLCache.shared = URLCache(memoryCapacity: 32 * 1024 * 1024, diskCapacity: 256 * 1024 * 1024)
        do {
            container = try ModelContainer(
                for: Track.self, Playlist.self, GameCategory.self, Game.self, PlaybackStateRecord.self
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
        let settings = AppSettings()
        _settings = State(initialValue: settings)
        _player = State(initialValue: PlayerService(settings: settings))
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView()
                if showSplash {
                    SplashView()
                        .zIndex(1)
                        .transition(.opacity)
                }
            }
            .environment(settings)
            .environment(player)
            .tint(Theme.accent)
            .preferredColorScheme(settings.appearance.colorScheme)
            .task {
                try? await Task.sleep(nanoseconds: UInt64(SplashView.displayDuration * 1_000_000_000))
                withAnimation(.easeOut(duration: 0.45)) {
                    showSplash = false
                }
            }
        }
        .modelContainer(container)
    }
}
