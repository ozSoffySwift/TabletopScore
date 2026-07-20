import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(PlayerService.self) private var player
    @State private var syncError: String?

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
        .task { await initialSync() }
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
        .alert(
            "Catalog",
            isPresented: Binding(
                get: { syncError != nil },
                set: { if !$0 { syncError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(syncError ?? "")
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
        do {
            try await CatalogSyncService(context: context)
                .syncIfNeeded(from: BackendConfig.catalogSource())
        } catch {
            syncError = String(localized: "Could not load the catalog: \(error.localizedDescription)")
        }
        // Restore the previous session's queue after the catalog exists.
        player.configure(context: context)
    }
}
