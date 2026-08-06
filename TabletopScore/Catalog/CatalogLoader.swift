import Foundation
import Observation
import SwiftData

/// Drives catalog loading for the app, offline-first.
///
/// App Review rejected 1.0 (2) under Guideline 2.1 — "content failed to load in
/// Home". The reviewer's device never reached the backend at all (the server
/// logs show zero connections from it while serving everyone else normally), so
/// the database stayed empty and Home showed its loading skeleton forever, with
/// no retry and no way to recover.
///
/// Three things prevent that now:
///
/// 1. **Seed from the bundle first.** A full catalog ships inside the app, so a
///    first launch with no connectivity still has every game and playlist.
///    Browsing works; only streaming needs the network.
/// 2. **Retry the network sync** with backoff, and again when the app returns to
///    the foreground — a captive portal or slow DNS at launch is no longer fatal.
/// 3. **Report failure only when there is nothing to show**, so the UI can offer
///    a retry instead of an endless skeleton.
@MainActor
@Observable
final class CatalogLoader {
    /// True while a load is in flight — the UI shows its skeleton for this.
    private(set) var isSyncing = false

    /// Set only when the app has no catalog to display *and* loading failed.
    /// When the bundled seed succeeded this stays nil even if the server is
    /// unreachable, because the user has content and nothing is broken.
    private(set) var failureMessage: String?

    /// Backoff between network attempts. Short: this runs during app launch.
    private static let retryDelays: [Duration] = [.seconds(1), .seconds(3)]

    func load(context: ModelContext) async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        let sync = CatalogSyncService(context: context)
        await seedFromBundleIfEmpty(using: sync, context: context)
        await refreshFromServer(using: sync, context: context)
    }

    // MARK: - Steps

    /// Applies the catalog bundled with the app when the database is empty.
    /// Local file, no network, so this effectively cannot fail in the field —
    /// which is exactly why it runs before the server call.
    private func seedFromBundleIfEmpty(using sync: CatalogSyncService, context: ModelContext) async {
        guard isCatalogEmpty(context) else { return }
        do {
            // `force` so the seed applies regardless of version bookkeeping left
            // over from a previous install.
            try await sync.syncIfNeeded(from: BundledCatalogSource(), force: true)
        } catch {
            // Nothing to do but continue to the network attempt, which is the
            // only remaining way to get content.
        }
    }

    private func refreshFromServer(using sync: CatalogSyncService, context: ModelContext) async {
        var attempt = 0
        while true {
            do {
                try await sync.syncIfNeeded(from: BackendConfig.catalogSource())
                failureMessage = nil
                return
            } catch {
                if attempt < Self.retryDelays.count {
                    try? await Task.sleep(for: Self.retryDelays[attempt])
                    attempt += 1
                    continue
                }
                // Out of retries. Only surface this if the user has nothing to
                // look at; otherwise the bundled catalog is serving them fine
                // and an error would be noise.
                failureMessage = isCatalogEmpty(context)
                    ? String(localized: "Could not load the catalog: \(error.localizedDescription)")
                    : nil
                return
            }
        }
    }

    private func isCatalogEmpty(_ context: ModelContext) -> Bool {
        let count = (try? context.fetchCount(FetchDescriptor<Game>())) ?? 0
        return count == 0
    }
}
