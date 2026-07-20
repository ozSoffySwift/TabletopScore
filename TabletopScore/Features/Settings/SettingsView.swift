import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var context

    @State private var cacheBytes = URLCache.shared.currentDiskUsage
    @State private var isRefreshingCatalog = false
    @State private var catalogMessage: String?

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section {
                Picker("Appearance", selection: $settings.appearance) {
                    Text("System").tag(AppearanceMode.system)
                    Text("Light").tag(AppearanceMode.light)
                    Text("Dark").tag(AppearanceMode.dark)
                }
                .pickerStyle(.segmented)
                .accessibilityLabel(Text("Appearance"))
            } header: {
                Text("Appearance")
            } footer: {
                Text("Dark is the classic candlelit look; System follows your device.")
            }
            .listRowBackground(Theme.surface)

            Section {
                Toggle("Stream over cellular", isOn: $settings.allowCellularStreaming)
                    .tint(Theme.accent)
            } header: {
                Text("Streaming")
            } footer: {
                Text("When off, playback only starts on Wi-Fi.")
            }
            .listRowBackground(Theme.surface)

            Section {
                Toggle("Hide classical music", isOn: $settings.hideClassicalMusic)
                    .tint(Theme.accent)
            } header: {
                Text("Content")
            } footer: {
                Text("Hides the Classical playlist and category from Library, Home, and Search.")
            }
            .listRowBackground(Theme.surface)

            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Slider(value: $settings.crossfadeDuration, in: 0...10, step: 0.5) {
                        Text("Crossfade")
                    }
                    .tint(Theme.accent)
                    .accessibilityValue(Text(crossfadeLabel))
                    Text(crossfadeLabel)
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
            } header: {
                Text("Crossfade")
            } footer: {
                Text("Overlap between tracks so the ambience never hard-cuts.")
            }
            .listRowBackground(Theme.surface)

            Section {
                LabeledContent("Image cache", value: cacheSizeLabel)
                Button("Clear cache", role: .destructive) {
                    URLCache.shared.removeAllCachedResponses()
                    cacheBytes = URLCache.shared.currentDiskUsage
                }
            } header: {
                Text("Storage")
            } footer: {
                Text("Music streams on demand and is not stored on this device. Offline downloads are coming in a future update.")
            }
            .listRowBackground(Theme.surface)

            Section {
                Toggle("Share anonymous usage data", isOn: $settings.shareAnonymousUsage)
                    .tint(Theme.accent)
            } header: {
                Text("Privacy")
            } footer: {
                Text("Helps improve TabletopScore by counting plays anonymously — a random install ID, never anything personal. Turning this off takes effect immediately.")
            }
            .listRowBackground(Theme.surface)

            Section {
                Button {
                    refreshCatalog()
                } label: {
                    if isRefreshingCatalog {
                        ProgressView()
                    } else {
                        Text("Refresh catalog now")
                    }
                }
                if let catalogMessage {
                    Text(catalogMessage)
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
            } header: {
                Text("Catalog")
            } footer: {
                Text("The catalog updates automatically once a day.")
            }
            .listRowBackground(Theme.surface)

            Section {
                LabeledContent("Version", value: appVersion)
                NavigationLink {
                    MusicCreditsView()
                } label: {
                    Label("Music Credits", systemImage: "music.quarternote.3")
                }
                .accessibilityHint(Text("Shows license credits for every track"))
                Link(destination: URL(string: "https://ozsoffyswift.github.io/TabletopScore/privacy.html")!) {
                    Label("Privacy Policy", systemImage: "hand.raised.fill")
                }
                .accessibilityHint(Text("Opens the privacy policy in your browser"))
                Link(destination: URL(string: "https://boardgamegeek.com")!) {
                    Label("Powered by BoardGameGeek", systemImage: "link")
                }
                .accessibilityHint(Text("Opens boardgamegeek.com"))
            } header: {
                Text("About")
            } footer: {
                Text("Game data and box art courtesy of BoardGameGeek. Usage statistics are anonymous and optional (see Privacy above). Developed by Oz Soffy")
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
            }
            .listRowBackground(Theme.surface)
        }
        .miniPlayerGap()
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("Settings")
        .toolbarBackground(Theme.background, for: .navigationBar)
        .onAppear { cacheBytes = URLCache.shared.currentDiskUsage }
    }

    private var crossfadeLabel: String {
        settings.crossfadeDuration == 0
            ? String(localized: "Off")
            : String(localized: "\(settings.crossfadeDuration, specifier: "%.1f") seconds")
    }

    private var cacheSizeLabel: String {
        ByteCountFormatter.string(fromByteCount: Int64(cacheBytes), countStyle: .file)
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func refreshCatalog() {
        isRefreshingCatalog = true
        catalogMessage = nil
        Task {
            defer { isRefreshingCatalog = false }
            do {
                let sync = CatalogSyncService(context: context)
                let updated = try await sync.syncIfNeeded(from: BackendConfig.catalogSource(), force: true)
                catalogMessage = updated
                    ? String(localized: "Catalog updated.")
                    : String(localized: "Catalog is already up to date.")
            } catch {
                catalogMessage = String(localized: "Update failed: \(error.localizedDescription)")
            }
        }
    }
}
