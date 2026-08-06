import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(PlayerService.self) private var player
    @Environment(\.scenePhase) private var scenePhase
    @State private var loader = CatalogLoader()

    var body: some View {
        @Bindable var player = player
        TabView {
            tab { HomeView() }
                .tabItem { Label("Home", systemImage: "house.fill") }
            tab { SearchView() }
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
            tab { LibraryView() }
                .tabItem { Label("Library", systemImage: "rectangle.stack.fill") }
            tab { SettingsView() }
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .background(Theme.background)
        .environment(loader)
        .task { await initialSync() }
        .onChange(of: scenePhase) { _, phase in
            // A launch that failed while offline shouldn't stay broken: retry
            // when the app comes back with (hopefully) a working connection.
            guard phase == .active else { return }
            Task { await loader.load(context: context) }
        }
        .alert(
            "Playback",
            isPresented: Binding(
                get: { player.playbackError != nil },
                set: { if !$0 { player.playbackError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(player.playbackError ?? "")
        }
    }

    /// Every tab gets the persistent mini player pinned above the tab bar.
    /// It floats as an overlay; screens reserve space for it with
    /// `.miniPlayerGap()` so it never hides scrollable content.
    private func tab<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        NavigationStack {
            content()
        }
        .overlay(alignment: .bottom) {
            MiniPlayerBar()
        }
    }

    private func initialSync() async {
        // Offline-first: seeds from the bundled catalog, then refreshes from the
        // server with retries. Failures surface in Home (with a retry) rather
        // than as a modal alert over an empty screen.
        await loader.load(context: context)
        // Restore the previous session's queue after the catalog exists.
        player.configure(context: context)
    }
}
