import SwiftUI
import SwiftData

/// Every track's license credit line, grouped by composer. Displaying this
/// screen is what satisfies CC-BY attribution for in-app music use
/// (see LICENSING.md) — do not remove it while any CC-BY track ships.
struct MusicCreditsView: View {
    @Query(sort: \Track.title) private var tracks: [Track]

    /// Composer name → credit lines, composers alphabetical.
    private var creditsByComposer: [(composer: String, credits: [String])] {
        var grouped: [String: Set<String>] = [:]
        for track in tracks {
            guard let credit = track.creditText else { continue }
            let composer = track.composer ?? String(localized: "Unknown composer")
            grouped[composer, default: []].insert(credit)
        }
        return grouped
            .map { (composer: $0.key, credits: $0.value.sorted()) }
            .sorted { $0.composer < $1.composer }
    }

    var body: some View {
        Group {
            if creditsByComposer.isEmpty {
                ContentUnavailableView(
                    "No credits yet",
                    systemImage: "music.quarternote.3",
                    description: Text("Track credits appear here once the catalog loads.")
                )
            } else {
                List {
                    ForEach(creditsByComposer, id: \.composer) { group in
                        Section {
                            ForEach(group.credits, id: \.self) { credit in
                                Text(credit)
                                    .font(.footnote)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        } header: {
                            Text(group.composer).foregroundStyle(Theme.textPrimary)
                        }
                        .listRowBackground(Theme.surface)
                    }
                    Section {
                    } footer: {
                        Text("Tracks credited above are used under their respective licenses (Creative Commons Attribution 4.0, the Pixabay Content License, or public domain). Music is streamed for listening within Table Score and is not offered for download.")
                            .font(.caption2)
                    }
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
            }
        }
        .miniPlayerGap()
        .background(Theme.background)
        .navigationTitle("Music Credits")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
    }
}
